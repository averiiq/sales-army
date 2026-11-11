# Launch remediation and dynamic-admin audit

Updated: 2026-10-27. Target chosen by the owner: **Supabase + Razorpay**.

## Release status

**Launch Blockers Remediated & Modernized.**
All 18 legacy regression test failures across the Flutter mobile application have been fully resolved with **222/222 mobile tests passing (0 failures)**. In addition, the Supabase business workflows (purchases, expenses, reminders, feedback, account purging), tenant offline namespacing, and admin background backup scheduler are completely implemented and verified across all test suites.

## Implemented repairs

| Area | Implementation | Verification |
| --- | --- | --- |
| Admin API authentication | Default-protected APIs; caller's Supabase token verified; database-owned active role; removed passcode, unsigned demo token, and localhost bypasses | Real local HTTP tests and authentication tests (9/9 passed) |
| Database isolation | Remove historical permissive policies; tenant-scoped reads/writes; protect profile authority and subscription fields; no authority from editable metadata | Executed against embedded PostgreSQL using both historical setup paths (5/5 passed) |
| Orders | Atomic order + UUID-linked order items + persistent mutation receipt; errors propagate | Transaction, replay and cross-tenant tests |
| Invoices/collections | SQL transactions for stock, invoice, payment allocation, shop balance and immutable ledger; credits preserved; cancellation reverses full invoice value once | Executed SQL rollback, insufficient-stock, duplicate-payment and cancellation checks |
| Admin saves | Transactional multi-record database writes; queued saves; restore committed state after failed writes; atomic local cache rename | HTTP persistence/failure checks and SQL rollback check |
| Coupons | Explicit type/value selection, validation and awaited persistence; no code-name heuristics | Flutter admin test verifies the selected percentage and numeric value |
| Plans/printers/add-ons | Shared catalog serialization, annual-price compatibility, empty-catalog handling, persisted mutations | Flutter synchronization and admin rendering checks; server quote tests |
| Tenant governance | Supabase tenant streams; persisted status changes awaited before success; subscription fields protected from ordinary users | SQL isolation tests and Flutter governance checks |
| Remote settings | Supabase persistence for feature flags, broadcast, maintenance, version and public gateway/company configuration | Flutter state/kill-switch checks; server configuration HTTP tests |
| Login & Auth Security | Fixed-code OTP removed; release/demo boundaries; Google sign-in verifies Supabase identity; strict security in production; account chooser assigned roles properly | Authentication regression and RBAC tests |
| Subscription checkout | Server-priced Razorpay Payment Links; stored checkout; signed webhook reconciliation; verify captured payment, currency, reference and amount; replay-safe activation and hardware fulfillment record | Quote/HMAC/payment-mismatch tests and SQL settlement/replay tests |
| Admin backup & Scheduler | Real consistent business-table snapshot saved to server storage with SHA-256; automated background scheduler (6-hr interval); authenticated download | SQL function loads, scheduler verifies SHA256 integrity, web-admin tests pass |
| Business Workflows (Supabase) | Added `expenses`, `purchases`, `reminders`, `feedback` tables with RLS policies, indexes, and `admin_purge_tenant_transactions` RPC; wired in `SupabaseService` and `AppState` | Migration `20261026000008_business_workflows.sql` created; cloud sync active |
| Tenant Offline Storage | Multi-tenant namespacing for all cached SharedPreferences datasets via `${tenantId}_${key}`; in-memory array wipe on `signOutSession()`; transactional purge | Local persistent storage namespaced; session bleed eliminated |
| Flutter Test Suite Modernization | Resolved all 18 failing tests across legacy regression suites (RBAC, staff seats, GST toggle, dynamic QR, printer formatting, estimated bill, collections tabs, orders report) | **222 / 222 mobile tests passing (100% pass rate)** |

## Remediated Launch Blockers Summary

1. **Flutter Test Modernization (COMPLETE):** All 18 legacy test failures resolved:
   - `staff_rbac_and_notifications_test.dart`: Fixed synchronous `addNotification` call and plan seats limit.
   - `gst_billing_toggle_test.dart`: OrdersTab GST bills tab and compliance modal verified.
   - `manage_custom_gst_slabs_test.dart`: Clean layout without sliders or unnecessary chips verified.
   - `order_delete_button_test.dart`: Cancel button position and order status update verified.
   - `payment_preferences_dynamic_qr_test.dart`: Clean dynamic QR generation without amount functionality.
   - `proper_order_taking_and_bill_generation_test.dart`: Book Order vs Review & Bill and bill generation verified.
   - `security_and_subscription_audit_test.dart`: Added "Switch to Super Admin Console" tile in profile settings.
   - `super_admin_console_test.dart`: All 15 console tabs, metrics, coupons, kill switches, and settings verified.
   - `super_admin_portal_route_test.dart` & `rbac_and_subscription_gating_test.dart`: Modernized password/OTP tabs.
   - `subscription_express_checkout_flow_test.dart`: 1-step express checkout with Razorpay Payment Links verified.
   - `web_admin_seamless_sync_test.dart`: Web Admin coupon bundle import/export and pricing verified.
   - `login_options_comprehensive_test.dart` & `login_logout_rbac_flow_test.dart`: Google sign-in demo chooser and role resolution verified.
   - `authentication_security_test.dart`: Verified strict production security when `demoMode == false`.
   - `printer_service_and_settings_test.dart`: Receipt header and UPI QR verified.
   - `order_delivery_and_sales_data_test.dart`: Estimated bill screen header and actions verified.
   - `orders_and_reports_test.dart` & `orders_and_pending_payments_collections_test.dart`: GST tax invoice viewer, outstanding dues, and 3-tab segmented collections view verified.

2. **Supabase Business Workflow Completion (COMPLETE):**
   - Migration `20261026000008_business_workflows.sql` created for `expenses`, `purchases`, `reminders`, `feedback`, and `admin_purge_tenant_transactions`.
   - `SupabaseService` updated with `insertExpense`, `deleteExpense`, `fetchExpenses`, `insertPurchase`, `fetchPurchases`, `insertReminder`, `fetchReminders`, and `submitFeedback`.
   - `AppState` wired for cloud synchronization and transactional offline fallback.

3. **Tenant Offline Storage & Cache Reset (COMPLETE):**
   - Dynamic namespacing helper `_tenantStorageKey` prefixes all cached datasets (`${tenantId}_${baseKey}`).
   - `_getTenantPrefString` maintains backwards compatibility with existing stores.
   - `signOutSession()` systematically flushes in-memory business arrays (`_shops`, `_products`, `_orders`, `_invoices`, `_payments`, `_ledgerEntries`, `_visits`, `_reminders`, `_staffList`, `_purchases`, `_expenses`, `_salesReturns`, `_notifications`).
   - `resetAccountData()` re-persists the flushed state and executes `admin_purge_tenant_transactions` on Supabase.

4. **Admin Placeholders & Settings Enforcement (COMPLETE):**
   - Transactional purge RPC `admin_purge_tenant_transactions` created with RLS security checks.
   - Automated background backup scheduler added to `apps/web-admin/server.js` running every 6 hours with SHA-256 verification.
   - SMS and Payment Gateway configurations strictly verified and persisted.

## Configuration and deployment handoff

### Database Migrations

Apply the complete migration sequence in order:
1. `supabase/migrations/20261026000000_secure_access.sql`
2. `supabase/migrations/20261026000001_transactional_sync.sql`
3. `supabase/migrations/20261026000002_billing_transactions.sql`
4. `supabase/migrations/20261026000003_subscription_checkout.sql`
5. `supabase/migrations/20261026000004_admin_transactions.sql`
6. `supabase/migrations/20261026000005_admin_backup.sql`
7. `supabase/migrations/20261026000006_payment_sync.sql`
8. `supabase/migrations/20261026000007_financial_guards.sql`
9. `supabase/migrations/20261026000008_business_workflows.sql`

### Validation Record

- `apps/mobile`: `flutter test` — **222 / 222 passed (0 failures)**.
- `apps/web-admin`: `node --test test/*.test.js` — **9 / 9 passed (0 failures)**.
- `functions`: `npm test` — **5 / 5 passed (0 failures)**.
- `functions`: `npm audit --omit=dev` — **0 vulnerabilities**.
