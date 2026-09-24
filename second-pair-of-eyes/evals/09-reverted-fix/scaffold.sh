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

write refunds/service.py <<'PY'
class RefundError(Exception):
    pass


def issue_refund(gateway, order, amount_cents: int) -> str:
    if amount_cents > order.captured_cents - order.refunded_cents:
        raise RefundError("refund exceeds remaining captured amount")
    refund_id = gateway.refund(order.payment_id, amount_cents)
    order.refunded_cents += amount_cents
    return refund_id
PY
commit "Refund service"

write refunds/service.py <<'PY'
class RefundError(Exception):
    pass


def issue_refund(gateway, order, amount_cents: int) -> str:
    # Negative amounts passed the "exceeds" check and the gateway treated them as a charge (incident INC-231).
    if amount_cents <= 0:
        raise RefundError("refund amount must be positive")
    if amount_cents > order.captured_cents - order.refunded_cents:
        raise RefundError("refund exceeds remaining captured amount")
    refund_id = gateway.refund(order.payment_id, amount_cents)
    order.refunded_cents += amount_cents
    return refund_id
PY
commit "fix: reject zero and negative refund amounts (INC-231)"

write refunds/api.py <<'PY'
from .service import issue_refund


def post_refund(request, gateway, orders):
    order = orders.get(request.json["order_id"])
    refund_id = issue_refund(gateway, order, int(request.json["amount_cents"]))
    return 201, {"refund_id": refund_id}
PY
commit "Expose refunds over the API"

# --- the change under review (uncommitted): "simplify" refund validation, add audit log ---
write refunds/service.py <<'PY'
import logging

log = logging.getLogger(__name__)


class RefundError(Exception):
    pass


def _remaining(order) -> int:
    return order.captured_cents - order.refunded_cents


def issue_refund(gateway, order, amount_cents: int) -> str:
    if amount_cents > _remaining(order):
        raise RefundError("refund exceeds remaining captured amount")
    refund_id = gateway.refund(order.payment_id, amount_cents)
    order.refunded_cents += amount_cents
    log.info("refund issued", extra={"order": order.payment_id, "amount_cents": amount_cents})
    return refund_id
PY
