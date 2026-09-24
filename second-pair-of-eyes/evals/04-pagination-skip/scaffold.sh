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

write package.json <<'JSON'
{ "name": "catalog", "version": "1.0.0", "scripts": { "test": "vitest run" },
  "devDependencies": { "vitest": "^2.0.0", "typescript": "^5.5.0" } }
JSON

write src/products.ts <<'TS'
export interface Product { id: string; name: string; priceCents: number }

export interface Db {
  query<T>(sql: string, params: unknown[]): Promise<T[]>;
}

export async function listAllProducts(db: Db): Promise<Product[]> {
  return db.query<Product>('SELECT id, name, price_cents AS "priceCents" FROM products ORDER BY id', []);
}
TS

write src/http.ts <<'TS'
import { Db, listAllProducts } from './products';

// GET /products — the storefront calls this with ?page=1 for the first page (see web/catalog.ts)
export async function getProducts(db: Db, query: Record<string, string>) {
  return { items: await listAllProducts(db) };
}
TS

write web/catalog.ts <<'TS'
export async function loadFirstPage() {
  const res = await fetch('/products?page=1&pageSize=20');
  return res.json();
}
TS
commit "Product listing"

# --- the change under review (uncommitted) ---
write src/products.ts <<'TS'
export interface Product { id: string; name: string; priceCents: number }

export interface Db {
  query<T>(sql: string, params: unknown[]): Promise<T[]>;
}

export async function listAllProducts(db: Db): Promise<Product[]> {
  return db.query<Product>('SELECT id, name, price_cents AS "priceCents" FROM products ORDER BY id', []);
}

export async function listProductsPage(db: Db, page: number, pageSize: number): Promise<Product[]> {
  const offset = page * pageSize;
  return db.query<Product>(
    'SELECT id, name, price_cents AS "priceCents" FROM products ORDER BY id LIMIT $1 OFFSET $2',
    [pageSize, offset],
  );
}
TS

write src/http.ts <<'TS'
import { Db, listProductsPage } from './products';

// GET /products — the storefront calls this with ?page=1 for the first page (see web/catalog.ts)
export async function getProducts(db: Db, query: Record<string, string>) {
  const page = Number(query.page ?? 1);
  const pageSize = Number(query.pageSize ?? 20);
  return { items: await listProductsPage(db, page, pageSize) };
}
TS
