# SalesArmy — Full Platform Audit

**Date:** 2026-11-22 · **Scope:** Bridge server (`apps/web-admin/server.js`), Cloudflare worker (`apps/web-admin/_worker.js`), Supabase migrations (19 files), Flutter app (`apps/mobile/lib`, ~78k LOC), web admin SPA, build config.
**Method:** read-only code review + targeted test runs. Live Supabase/Cloudflare settings were **not** inspected — items marked *(verify live)* depend on dashboard config.

> ⚠️ This file describes exploitable weaknesses. Do not push it to a public repo or share outside the team until the Critical items are fixed.

---

## Summary

| Severity | Count | Theme |
|---|---|---|
| 🔴 Critical | 6 | Anyone on the internet can become super admin, take over accounts, or write financial records into any agency |
| 🟠 High | 9 | Broken money flows (ledger drift), fake payment/backup actions, broken admin features |
| 🟡 Medium | 8 | Data integrity, error leakage, stale docs/tests |
| 🟢 Good | — | Server-side checkout pricing, webhook HMAC, RLS read isolation, profile authority trigger, web admin XSS escaping |

**Bottom line:** core selling flows work locally, but the **cloud backend is not safe to run with real customer data** until C-1 … C-6 are fixed. Most fixes are small (a few lines of SQL / one auth gate).

---

## 🔴 Critical

### C-1. Self-service super admin via signup metadata
**Where:** `supabase/migrations/20261103000001_fix_handle_new_user_default_role.sql`
`handle_new_user()` takes `role` and `tenant_id` from `raw_user_meta_data`, which the **user sets themselves** in `supabase.auth.signUp({ options: { data } })`. The anon key is public (`GET /api/config/supabase` returns it unauthenticated).
**Exploit:** sign up with `data: { role: 'super_admin' }` → profile is `super_admin` → `is_super_admin()` true in every RLS policy and in the bridge's `verifyAdminAuth`. With `{ role: 'owner', tenant_id: '<victim>' }` → full control of one agency.
**Fix:** read role/tenant **only** from `raw_app_meta_data` (service-role only). Default new users to `role = NULL`/`'pending'`, `tenant_id = NULL`. Audit existing `profiles` for unexpected `super_admin` rows. *(Also verify live: is public email signup enabled?)*

### C-2. Anonymous writes to any tenant's invoices/payments/orders
**Where:** `20261103000000_fix_invoice_and_order_permissions.sql`
`assert_sales_access()` now **skips the tenant check when `auth.uid()` is NULL**, and `record_invoice`, `record_payment`, `cancel_invoice`, `sync_save_order` are `GRANT … TO anon`.
**Exploit:** with only the public anon key, call `rpc/record_payment` with any `p_tenant` → fake payments wipe dues, fake invoices inflate dues, real invoices get cancelled. Tenant IDs are guessable (`tenant_<slug>_<6 digits>`) and listed by the open worker (C-3).
**Fix:** restore the 26-Oct version (reject `auth.uid() IS NULL`), `REVOKE EXECUTE … FROM anon`. Offline sessions should queue in the outbox and sync after login, not write anonymously.

### C-3. Cloudflare worker has no authentication
**Where:** `apps/web-admin/_worker.js` (deployed via root `wrangler.toml`; `.wrangler/` present)
Only `/api/auth/tenants` checks a token. Every other route runs with the **service-role key** and is public: `DELETE /api/platform/user/:id`, `POST /api/platform/user/reset-password` (**take over any account incl. super admin**), `GET /api/platform/all|users|tenants`, `POST /api/platform/update`, coupon/settings writes.
**Fix:** immediately undeploy or rotate the service-role key if deployed *(verify live: `wrangler deployments list`)*. Port `security.authenticate` + super_admin gate from `server.js`, or delete the worker and deploy only `server.js`.

### C-4. Mobile agency signup resets existing accounts' passwords
**Where:** `apps/mobile/lib/core/services/supabase_service.dart` → `registerAgencyOwnerAndSeed`
If the email already exists, it calls the Admin API to **set that account's password to the newly typed one** and move it to the new tenant. Requires the service-role key in the app.
**Exploit (when built with the key):** "register" with the victim's email → you now own their account.
**Status:** today's builds have no `--dart-define`, so the key is empty — the takeover is dormant, but signup also can't create real cloud accounts. **Fix:** delete all `admin*` methods and the service-role constant from the app; route signup through `POST /api/auth/signup` (server already handles it correctly and rejects existing emails).

### C-5. "Launch Razorpay Checkout" records fake captured payments
**Where:** `collect_payment_dialog.dart` → `_launchRazorpayCheckout`
No gateway is opened; after a 600 ms delay it records an `Online / UPI` payment with a fabricated `rzp_live_…` reference, reduces dues and shows "captured". "Share Payment Link" copies a fake `rzp.io` URL.
**Fix:** hide both buttons until real Razorpay Payment Links (server `/api/platform/gateway/create-link` already exists) are wired, and only record the payment from the verified webhook.

### C-6. Secrets on disk / in git
- **GitHub personal access token embedded in the git remote URL** (`.git/config`, `origin`). Revoke it at GitHub → Settings → Developer settings → Tokens, then `git remote set-url origin https://github.com/averiiq/sales-army.git` and use a credential manager.
- `apps/web-admin/data/gateway_config.json` (Razorpay keySecret/webhookSecret) is **committed**; currently test-mode placeholders, but the server writes real secrets back to this tracked file. Add `apps/web-admin/data/` to `.gitignore`, `git rm --cached` it, keep secrets in env vars.
- `apps/mobile/.env` holds the **service-role key** (not tracked, not bundled — OK today). Remove it from the mobile folder so it can't be passed to a build by mistake.

---

## 🟠 High

| # | Issue | Where | Impact / Fix |
|---|---|---|---|
| H-1 | **13-Nov RLS migration likely fails to apply**: `order_items.order_id` (uuid) compared to `orders.order_id` (varchar) | `20261113000000_fix_rls_security_audit.sql` | Postgres rejects `uuid = varchar`; whole migration rolls back, so its tenant/profile fixes may not be live. Use `o.id = order_items.order_id`. *(verify live: `select * from pg_policies where tablename='order_items'`)* |
| H-2 | **Overpayment is silently lost & ledger drifts** — outstanding is clamped to ₹0 | `app_state.dart` `recordPayment`, `processSalesReturn`, `deleteInvoice` | Due ₹100, pay ₹150 → ₹0 (₹50 vanishes); delete that payment → due becomes ₹150. Ledger `amount` ≠ `balanceAfter − before`. Allow negative balance (advance/credit) or reject overpayment. |
| H-3 | **Deleting a payment doesn't un-mark invoices** | `deletePayment`, `updatePayment` | Invoices stay "paid"/"partial" after the payment is removed. `updatePayment` also writes no ledger entry. |
| H-4 | **Deleting a partly-paid invoice removes its full total from dues** | `deleteInvoice` | Should subtract only the unpaid part (doc claims it does). Understates other invoices' dues. |
| H-5 | **Clients write absolute `current_outstanding`** to `shops` | `updateShopOutstanding` + `sales_write` policy | Any sales rep can set a shop's dues to anything; two devices overwrite each other. Compute balances server-side from ledger in RPCs only. |
| H-6 | **Fake backup before account reset** | `reset_account_dialog.dart` | "Archive saved to downloads!" but nothing is saved → user resets and loses data. Use the real JSON export (`SyncAndBackupScreen`) or remove the button. |
| H-7 | **Manual subscription settle always fails** — wrong RPC params | `server.js` `/api/platform/subscriptions/settle` | Sends `p_checkout_id…`; SQL takes `p_id, p_link, p_payment, p_amount`. |
| H-8 | **Login treats profile-less users as super_admin** | `server.js` `/api/auth/login` L1754, `_worker.js` L164 | Server gate still blocks APIs, but the portal UI trusts the response role. Return 403 instead; drop the `tenant_shree_ganesh_traders` fallback. |
| H-9 | **Freemium guarantee broken in cloud** | `assert_sales_access` | Requires `subscription_end_date > now()`; server signup sets a 14-day trial end date → after trial, cloud invoices/payments fail. Exempt core selling RPCs from the expiry check. |

---

## 🟡 Medium

1. **Mobile→bridge sync is dead code**: `postHardwareOrderToBridge`, `syncOrderToServerBridge`, `syncShopToServerBridge`, tenant/user sync send **no auth header** (server returns 401) and are disabled in release builds. Hardware orders reach the admin only if Supabase insert works. Remove or route through `PlatformApi` with the session token.
2. **`/api/platform/backup` called by the app no longer exists** on the server → admin backup action errors.
3. **Public signup is unauthenticated tenant creation**: `email_confirm: true` (no email verification — register with someone else's email), client-chosen `planId`, tenant row written **before** auth user creation (orphan tenants when email exists). Rate limit is IP-only.
4. **Raw `err.message` returned in 500s** across `server.js` (DB/internal details leak).
5. **Fire-and-forget cloud writes** (`updatePayment`, `deletePayment`, `updateInvoice`, `updateShopOutstanding`) are not awaited and errors are swallowed → silent local/cloud divergence. `recordPayment` awaits; the rest should too, or go through the outbox.
6. **Ledger IDs use `millisecondsSinceEpoch`** — invoice + payment in the same billing action can collide. Use UUIDs.
7. **Receipt WhatsApp / Thermal Print buttons only show a toast** (`showPaymentReceiptModal`). Bills use the real `PrinterService`; reuse it here and `url_launcher` for WhatsApp.
8. **OAuth deep link not verified** (`autoVerify="false"`, custom scheme) — another app can intercept the login callback. Move to App Links.

---

## Docs & tests drift

- `PROJECT_CONTEXT.md` describes **Firebase Functions, `firestore.rules`, `storage.rules`, SSE `/api/platform/events`** — none exist. `_worker.js` and `security.js`/`checkout.js` are undocumented. Endpoint tables omit ~35 server routes.
- "42 suites, 100% passing" is stale — see test results below.
- `orders_and_reports_test.dart` asserts UI that no longer exists ("Record Collection", "Cancel", fixed ₹ totals).

**Test run (2026-11-22):** see the "Test results" section at the bottom.

---

## ✅ What's done well

- Checkout amount computed server-side from published catalog; Razorpay webhook uses HMAC + `timingSafeEqual`; payment link amount re-verified before settlement.
- `protect_profile_authority` / `protect_tenant_governance` triggers block self-escalation via UPDATE.
- Read RLS (`member_read`) isolates tenants for ledger, payments, invoices, orders; ledger has no direct client write policy.
- `server.js`: origin allow-list, CSP/HSTS/frame headers, body-size cap, per-email login throttling, admin routes gated on DB role (not JWT claims).
- Web admin escapes HTML in toasts and search; most templates use `escapeHtml`.
- Plaintext password storage (old C-2) and hardcoded service-role default (old C-1) were removed.
- The universal OTP bypass (`123456`) was removed; OTP is verified only by Supabase.

---

## Test results (full `flutter test`, 2026-11-22)

- **~58 tests failing** (exact pass total not captured). The run exits 0 because output was piped.
- Many failures are **stale assertions after intentional security fixes** — e.g. `auth_login_recovery_test.dart` still expects the removed universal OTP `123456`; `orders_and_reports_test.dart` expects removed UI.
- Action: triage into (a) delete/rewrite tests that assert removed insecure behaviour, (b) fix real regressions. Until then the suite cannot catch new bugs.
- Static analysis: 0 errors/warnings in the files touched today (only `material.dart` deprecation infos).

---

## Fix order (suggested)

1. **Today:** C-3 (undeploy worker / rotate service key), C-6 (revoke GitHub token), C-1 + C-2 (one SQL migration), audit `profiles` for rogue `super_admin`.
2. **This week:** C-4 (strip admin APIs from app), C-5 + H-6 (hide fake buttons), H-1, H-7, H-8, H-9.
3. **Next:** H-2 … H-5 ledger correctness (move balance math into RPCs), Medium items, docs/tests refresh.
