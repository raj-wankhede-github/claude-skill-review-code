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

write accounts/users.py <<'PY'
import hashlib
import os

MIN_PASSWORD_LENGTH = 8
_users = {}  # email -> {"email", "salt", "hash"}


def _hash(password: str, salt: bytes) -> bytes:
    return hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 200_000)


def signup(email: str, password: str) -> dict:
    if len(password) < MIN_PASSWORD_LENGTH:
        raise ValueError("password too short")
    if email in _users:
        raise ValueError("email already registered")
    salt = os.urandom(16)
    _users[email] = {"email": email, "salt": salt, "hash": _hash(password, salt)}
    return {"email": email}


def login(email: str, password: str) -> bool:
    user = _users.get(email)
    if not user:
        return False
    return _hash(password, user["salt"]) == user["hash"]
PY
commit "User signup and login"

git checkout -q -b feature/PROJ-7-case-insensitive-email

write accounts/users.py <<'PY'
import hashlib
import os

MIN_PASSWORD_LENGTH = 6
_users = {}  # email -> {"email", "salt", "hash"}


def _hash(password: str, salt: bytes) -> bytes:
    return hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 200_000)


def normalize_email(email: str) -> str:
    return email.strip().lower()


def signup(email: str, password: str) -> dict:
    email = normalize_email(email)
    if len(password) < MIN_PASSWORD_LENGTH:
        raise ValueError("password too short")
    if email in _users:
        raise ValueError("email already registered")
    salt = os.urandom(16)
    _users[email] = {"email": email, "salt": salt, "hash": _hash(password, salt)}
    return {"email": email}


def login(email: str, password: str) -> bool:
    user = _users.get(email)
    if not user:
        return False
    return _hash(password, user["salt"]) == user["hash"]
PY
git add -A
git commit -q -F - <<'MSG'
PROJ-7: make email addresses case-insensitive

Users who sign up as Ada@Example.com and log in as ada@example.com are
currently told their account doesn't exist. Normalize emails (trim +
lowercase) on signup and on login so both refer to the same account.
MSG
