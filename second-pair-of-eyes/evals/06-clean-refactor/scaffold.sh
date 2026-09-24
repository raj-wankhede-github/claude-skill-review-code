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

write billing/totals.py <<'PY'
from decimal import Decimal, ROUND_HALF_UP

CENT = Decimal("0.01")


def order_total(lines, tax_rate: Decimal) -> Decimal:
    subtotal = Decimal("0")
    for line in lines:
        subtotal += Decimal(line["unit_price"]) * line["quantity"]
    tax = (subtotal * tax_rate).quantize(CENT, rounding=ROUND_HALF_UP)
    return subtotal + tax


def invoice_total(lines, tax_rate: Decimal, discount: Decimal) -> Decimal:
    subtotal = Decimal("0")
    for line in lines:
        subtotal += Decimal(line["unit_price"]) * line["quantity"]
    subtotal -= discount
    tax = (subtotal * tax_rate).quantize(CENT, rounding=ROUND_HALF_UP)
    return subtotal + tax
PY

write tests/test_totals.py <<'PY'
from decimal import Decimal
from billing.totals import order_total, invoice_total

LINES = [{"unit_price": "9.99", "quantity": 3}, {"unit_price": "0.50", "quantity": 1}]

def test_order_total():
    assert order_total(LINES, Decimal("0.19")) == Decimal("36.26")

def test_invoice_total_with_discount():
    assert invoice_total(LINES, Decimal("0.19"), Decimal("5.00")) == Decimal("30.31")

def test_empty_order():
    assert order_total([], Decimal("0.19")) == Decimal("0.00")
PY
commit "Order and invoice totals"

# --- the change under review (uncommitted): extract the duplicated subtotal/tax logic ---
write billing/totals.py <<'PY'
from decimal import Decimal, ROUND_HALF_UP

CENT = Decimal("0.01")


def _subtotal(lines) -> Decimal:
    subtotal = Decimal("0")
    for line in lines:
        subtotal += Decimal(line["unit_price"]) * line["quantity"]
    return subtotal


def _with_tax(amount: Decimal, tax_rate: Decimal) -> Decimal:
    tax = (amount * tax_rate).quantize(CENT, rounding=ROUND_HALF_UP)
    return amount + tax


def order_total(lines, tax_rate: Decimal) -> Decimal:
    return _with_tax(_subtotal(lines), tax_rate)


def invoice_total(lines, tax_rate: Decimal, discount: Decimal) -> Decimal:
    return _with_tax(_subtotal(lines) - discount, tax_rate)
PY
