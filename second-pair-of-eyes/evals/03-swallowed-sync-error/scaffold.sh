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

write crm_sync/client.py <<'PY'
import requests


class CrmError(Exception):
    pass


class CrmClient:
    def __init__(self, base_url: str, token: str):
        self.base_url = base_url
        self.token = token

    def upsert_contact(self, contact: dict) -> dict:
        resp = requests.put(
            f"{self.base_url}/contacts/{contact['email']}",
            json=contact,
            headers={"Authorization": f"Bearer {self.token}"},
            timeout=10,
        )
        if resp.status_code >= 400:
            raise CrmError(f"CRM returned {resp.status_code}")
        return resp.json()
PY

write crm_sync/job.py <<'PY'
import logging

log = logging.getLogger(__name__)


def sync_contacts(client, contacts):
    """Push contacts to the CRM. Called nightly by the scheduler; a non-'ok' status pages on-call."""
    for contact in contacts:
        client.upsert_contact(contact)
    return {"status": "ok", "synced": len(contacts)}
PY
commit "Nightly CRM contact sync"

# --- the change under review (uncommitted) ---
write crm_sync/job.py <<'PY'
import logging

log = logging.getLogger(__name__)


def sync_contacts(client, contacts):
    """Push contacts to the CRM. Called nightly by the scheduler; a non-'ok' status pages on-call."""
    synced = 0
    for contact in contacts:
        try:
            client.upsert_contact(contact)
            synced += 1
        except Exception:
            # don't let one bad contact kill the whole run
            log.warning("skipping contact")
            continue
    return {"status": "ok", "synced": len(contacts)}
PY
