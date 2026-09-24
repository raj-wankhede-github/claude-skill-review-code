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

write REVIEW.md <<'MD'
# Review rules for this repository

1. Money is always `Decimal` (or integer cents). Never `float` — not in models, not in arithmetic,
   not in JSON parsing (`json.loads(..., parse_float=Decimal)`).
2. Every new HTTP endpoint is listed in `docs/api.md` in the same change.
3. Handlers never talk to the database directly; they go through a function in `shop/repo.py`.
MD

write docs/api.md <<'MD'
# API

| Method | Path | Handler |
| ------ | ---- | ------- |
| GET | /cart | `shop.handlers.get_cart` |
MD

write shop/repo.py <<'PY'
from decimal import Decimal

_carts = {}  # user_id -> list of {"sku", "price": Decimal, "qty": int}


def get_cart(user_id):
    return _carts.setdefault(user_id, [])


def add_item(user_id, sku, price: Decimal, qty: int):
    get_cart(user_id).append({"sku": sku, "price": price, "qty": qty})
PY

write shop/handlers.py <<'PY'
from decimal import Decimal
from . import repo


def get_cart(request):
    items = repo.get_cart(request.user_id)
    total = sum((i["price"] * i["qty"] for i in items), Decimal("0"))
    return 200, {"items": items, "total": str(total)}
PY
commit "Cart endpoint"

# --- the change under review (uncommitted): add items to the cart ---
write shop/handlers.py <<'PY'
from decimal import Decimal
from . import repo


def get_cart(request):
    items = repo.get_cart(request.user_id)
    total = sum((i["price"] * i["qty"] for i in items), Decimal("0"))
    return 200, {"items": items, "total": str(total)}


def add_to_cart(request):
    body = request.json
    price = float(body["price"])
    qty = int(body.get("qty", 1))
    repo.add_item(request.user_id, body["sku"], price, qty)
    return 201, {"added": body["sku"]}
PY

write shop/routes.py <<'PY'
from . import handlers

ROUTES = [
    ("GET", "/cart", handlers.get_cart),
    ("POST", "/cart/items", handlers.add_to_cart),
]
PY
