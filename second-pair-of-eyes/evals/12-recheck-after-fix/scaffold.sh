#!/usr/bin/env bash
# Builds the fixture repository in the (empty) run workspace.
set -euo pipefail

init_repo() {
  git init -q -b main .
  git config user.name "Eval Author"
  git config user.email "eval@example.com"
  git config commit.gpgsign false
  git config core.autocrlf false
}

# commit "<message>" — stage everything and commit
commit() {
  git add -A
  git commit -q -m "$1"
}

# write <path> — write stdin to path, creating parent directories
write() {
  mkdir -p "$(dirname "$1")"
  cat > "$1"
}

init_repo

write app/db.py <<'PY'
import sqlite3

def connect(path="app.db"):
    conn = sqlite3.connect(path)
    conn.execute("CREATE TABLE IF NOT EXISTS accounts (user_id TEXT PRIMARY KEY, balance_cents INTEGER NOT NULL)")
    conn.execute("CREATE TABLE IF NOT EXISTS processed_events (event_id TEXT PRIMARY KEY)")
    return conn
PY

write app/webhooks.py <<'PY'
"""Payment provider webhooks. The provider delivers each event at least once and retries on any non-2xx."""
import hmac
import hashlib
import json

WEBHOOK_SECRET_ENV = "PAYMENTS_WEBHOOK_SECRET"


def verify_signature(secret: str, body: bytes, signature: str) -> bool:
    expected = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)


def handle_event(conn, secret: str, body: bytes, signature: str):
    if not verify_signature(secret, body, signature):
        return 401, {"error": "bad signature"}
    event = json.loads(body)
    if event["type"] == "payment.refunded":
        # refunds are handled manually by finance for now
        return 200, {"ignored": True}
    return 200, {"ignored": True}
PY

write tests/test_webhooks.py <<'PY'
import hmac, hashlib, json
from app.db import connect
from app.webhooks import handle_event

SECRET = "test-secret"

def sign(body):
    return hmac.new(SECRET.encode(), body, hashlib.sha256).hexdigest()

def test_rejects_bad_signature():
    conn = connect(":memory:")
    status, _ = handle_event(conn, SECRET, b"{}", "nope")
    assert status == 401
PY
commit "Add payment webhook endpoint with signature verification"

# --- the change that was reviewed earlier (uncommitted) ---
write app/webhooks.py <<'PY'
"""Payment provider webhooks. The provider delivers each event at least once and retries on any non-2xx."""
import hmac
import hashlib
import json

WEBHOOK_SECRET_ENV = "PAYMENTS_WEBHOOK_SECRET"


def verify_signature(secret: str, body: bytes, signature: str) -> bool:
    expected = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)


def credit_account(conn, user_id: str, amount_cents: int):
    row = conn.execute("SELECT balance_cents FROM accounts WHERE user_id = ?", (user_id,)).fetchone()
    balance = row[0] if row else 0
    conn.execute(
        "INSERT OR REPLACE INTO accounts (user_id, balance_cents) VALUES (?, ?)",
        (user_id, balance + amount_cents),
    )
    conn.commit()


def handle_event(conn, secret: str, body: bytes, signature: str):
    if not verify_signature(secret, body, signature):
        return 401, {"error": "bad signature"}
    event = json.loads(body)
    if event["type"] == "payment.succeeded":
        data = event["data"]
        credit_account(conn, data["user_id"], data["amount_cents"])
        conn.execute("INSERT INTO processed_events (event_id) VALUES (?)", (event["id"],))
        conn.commit()
        return 200, {"credited": data["amount_cents"]}
    if event["type"] == "payment.refunded":
        # refunds are handled manually by finance for now
        return 200, {"ignored": True}
    return 200, {"ignored": True}
PY

write tests/test_webhooks.py <<'PY'
import hmac, hashlib, json
from app.db import connect
from app.webhooks import handle_event

SECRET = "test-secret"

def sign(body):
    return hmac.new(SECRET.encode(), body, hashlib.sha256).hexdigest()

def test_rejects_bad_signature():
    conn = connect(":memory:")
    status, _ = handle_event(conn, SECRET, b"{}", "nope")
    assert status == 401

def test_credits_account_on_payment():
    conn = connect(":memory:")
    body = json.dumps({"id": "evt_1", "type": "payment.succeeded",
                       "data": {"user_id": "u1", "amount_cents": 500}}).encode()
    status, resp = handle_event(conn, SECRET, body, sign(body))
    assert status == 200
    assert conn.execute("SELECT balance_cents FROM accounts WHERE user_id='u1'").fetchone()[0] == 500
PY

# Snapshot of the reviewed working tree, exactly as the skill records it.
snap=$(git stash create)
head=$(git rev-parse HEAD)
echo "reviews/" >> .git/info/exclude
mkdir -p reviews
cat > reviews/previous.md <<META
<!-- second-pair-of-eyes
repo: $(pwd)
target: uncommitted
diff: git diff HEAD
mode: deep
date: 2026-09-20 10:15
head: $head
snapshot: $snap
untracked: -
-->
META
cat >> reviews/previous.md <<'MD'
# Second Pair of Eyes Review

**Reviewed:** uncommitted changes (2 files) · **Mode:** deep · **Reviewer:** independent (fresh context)
**Findings:** 0 CRITICAL · 1 HIGH · 1 MEDIUM · 0 LOW · 0 INFO

## Summary

The change starts crediting accounts when a `payment.succeeded` webhook arrives. The provider
delivers events at least once, and the handler does not guard against redelivery.

## Findings

### [HIGH] Redelivered payment events credit the account again

**Type:** Confirmed defect
**Location:** `app/webhooks.py:30`

**Problem:** `handle_event` credits the account without checking `processed_events` first.
**Why it matters:** Customers receive the same credit multiple times.
**How it can happen:** The provider redelivers `evt_1` (at-least-once delivery, retries on non-2xx). The second delivery credits again; the `processed_events` INSERT then raises an IntegrityError, the handler fails with a 5xx, and the provider retries — crediting again each time.
**Suggested direction:** Check and record the event id before crediting, in the same transaction, and return 2xx for already-processed events.

### [MEDIUM] Credit and event record are not written atomically

**Type:** Confirmed defect
**Location:** `app/webhooks.py:14-21`, `app/webhooks.py:30-31`

**Problem:** `credit_account` commits the balance before the event id is recorded, and the balance update is a read-modify-write.
**Why it matters:** A crash between the two commits, or two concurrent deliveries, leaves the balance and the event log inconsistent.
**How it can happen:** Process dies after `credit_account` commits; the retry sees no `processed_events` row and credits again.
**Suggested direction:** One transaction for the event record and the balance update; an atomic `UPDATE … SET balance_cents = balance_cents + ?`.

## Diff Hygiene

Clean.

## Things I Specifically Checked

- Signature verification — unchanged and still runs first.
- Team rules — none found. History — nothing relevant.

## Test Gaps

- Same event delivered twice — the account must be credited once and both deliveries must return 2xx.

## Questions / Assumptions

- Assumption: the provider retries on any non-2xx response (stated in the module docstring).
MD

# --- the fix under review now (uncommitted, on top of the reviewed change) ---
write app/webhooks.py <<'PY'
"""Payment provider webhooks. The provider delivers each event at least once and retries on any non-2xx."""
import hmac
import hashlib
import json

WEBHOOK_SECRET_ENV = "PAYMENTS_WEBHOOK_SECRET"


def verify_signature(secret: str, body: bytes, signature: str) -> bool:
    expected = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)


def credit_account(conn, user_id: str, amount_cents: int):
    row = conn.execute("SELECT balance_cents FROM accounts WHERE user_id = ?", (user_id,)).fetchone()
    balance = row[0] if row else 0
    conn.execute(
        "INSERT OR REPLACE INTO accounts (user_id, balance_cents) VALUES (?, ?)",
        (user_id, balance + amount_cents),
    )
    conn.commit()


def already_processed(conn, event_id: str) -> bool:
    return conn.execute("SELECT 1 FROM processed_events WHERE event_id = ?", (event_id,)).fetchone() is not None


def handle_event(conn, secret: str, body: bytes, signature: str):
    if not verify_signature(secret, body, signature):
        return 401, {"error": "bad signature"}
    event = json.loads(body)
    if event["type"] == "payment.succeeded":
        if already_processed(conn, event["id"]):
            return 409, {"error": "duplicate event"}
        data = event["data"]
        credit_account(conn, data["user_id"], data["amount_cents"])
        conn.execute("INSERT INTO processed_events (event_id) VALUES (?)", (event["id"],))
        conn.commit()
        return 200, {"credited": data["amount_cents"]}
    if event["type"] == "payment.refunded":
        # refunds are handled manually by finance for now
        return 200, {"ignored": True}
    return 200, {"ignored": True}
PY

cat >> tests/test_webhooks.py <<'PY'

def test_duplicate_event_is_rejected():
    conn = connect(":memory:")
    body = json.dumps({"id": "evt_2", "type": "payment.succeeded",
                       "data": {"user_id": "u2", "amount_cents": 700}}).encode()
    handle_event(conn, SECRET, body, sign(body))
    status, _ = handle_event(conn, SECRET, body, sign(body))
    assert status == 409
    assert conn.execute("SELECT balance_cents FROM accounts WHERE user_id='u2'").fetchone()[0] == 700
PY
