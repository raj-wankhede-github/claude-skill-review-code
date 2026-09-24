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
{ "name": "billing-api", "version": "1.0.0", "main": "src/server.js",
  "dependencies": { "express": "^4.19.2" } }
JSON

write src/auth.js <<'JS'
// Populates req.user from the session cookie; rejects anonymous requests.
function requireUser(req, res, next) {
  if (!req.session || !req.session.user) return res.status(401).json({ error: 'unauthenticated' });
  req.user = req.session.user;
  next();
}
module.exports = { requireUser };
JS

write src/store.js <<'JS'
const invoices = new Map(); // id -> { id, userId, amountCents, pdfUrl }
module.exports = {
  getInvoice: (id) => invoices.get(id),
  listInvoicesForUser: (userId) => [...invoices.values()].filter((i) => i.userId === userId),
  _invoices: invoices,
};
JS

write src/routes/invoices.js <<'JS'
const express = require('express');
const { requireUser } = require('../auth');
const store = require('../store');

const router = express.Router();

router.get('/invoices', requireUser, (req, res) => {
  res.json(store.listInvoicesForUser(req.user.id));
});

module.exports = router;
JS

write src/server.js <<'JS'
const express = require('express');
const app = express();
app.use('/api', require('./routes/invoices'));
module.exports = app;
JS
commit "Invoice listing endpoint"

# --- the change under review (uncommitted) ---
write src/routes/invoices.js <<'JS'
const express = require('express');
const { requireUser } = require('../auth');
const store = require('../store');

const router = express.Router();

router.get('/invoices', requireUser, (req, res) => {
  res.json(store.listInvoicesForUser(req.user.id));
});

// Download a single invoice (used by the new "Download PDF" button)
router.get('/invoices/:id', requireUser, (req, res) => {
  const invoice = store.getInvoice(req.params.id);
  if (!invoice) return res.status(404).json({ error: 'not found' });
  res.json(invoice);
});

module.exports = router;
JS
