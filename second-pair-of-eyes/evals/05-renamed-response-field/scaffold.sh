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

write api/serializers.py <<'PY'
def serialize_user(user) -> dict:
    return {
        "id": user.id,
        "user_name": user.name,
        "email": user.email,
    }
PY

write api/views.py <<'PY'
from .serializers import serialize_user


def get_profile(request, repo):
    user = repo.get(request.user_id)
    return 200, serialize_user(user)
PY

write web/src/profile.js <<'JS'
export async function renderProfile(el) {
  const res = await fetch('/api/profile');
  const body = await res.json();
  el.querySelector('.name').textContent = body.user_name;
  el.querySelector('.email').textContent = body.email;
}
JS

write tests/test_serializers.py <<'PY'
from types import SimpleNamespace
from api.serializers import serialize_user

def test_serialize_user():
    u = SimpleNamespace(id=1, name="Ada", email="ada@example.com")
    assert serialize_user(u)["user_name"] == "Ada"
PY
commit "Profile API and page"

# --- the change under review (uncommitted): "consistent naming" cleanup ---
write api/serializers.py <<'PY'
def serialize_user(user) -> dict:
    return {
        "id": user.id,
        "username": user.name,
        "email": user.email,
    }
PY

write tests/test_serializers.py <<'PY'
from types import SimpleNamespace
from api.serializers import serialize_user

def test_serialize_user():
    u = SimpleNamespace(id=1, name="Ada", email="ada@example.com")
    assert serialize_user(u)["username"] == "Ada"
PY
