SalesArmy Mobile App — Full Audit Report

Date: 2026-11-03 · Scope: apps/mobile/lib (74,700 LOC across 116 files) · Mode: Read-only research

---
Executive Summary

Dimension: Feature completeness
Score: 8.5/10
Verdict: Core distributor workflows (order → bill → collect) are production-ready
────────────────────────────────────────
Dimension: Data layer / sync
Score: 6.5/10
Verdict: RPC-first design is solid, but notification channel leaks and sign-out cleanup gaps remain
────────────────────────────────────────
Dimension: Code quality
Score: 6/10
Verdict: 0 analyze errors, 50 test files passing at 92%, but 10 screens exceed 1,500 lines
────────────────────────────────────────
Dimension: Architecture
Score: 4/10
Verdict: Monolithic AppState (5,549 LOC) + 9 of 12 features skip the domain layer
────────────────────────────────────────
Dimension: Security
Score: 4/10
Verdict: 3 critical issues: service_role key in binary, plaintext passwords, unverified deep link
────────────────────────────────────────
Dimension: Overall deployment readiness
Score: 6.5/10
Verdict: Ship-worthy for core distribution; security must be hardened before public launch

---
🔴 Critical Findings — Must Fix Before Launch

C-1. Supabase service_role key committed to the mobile binary

File: lib/core/services/supabase_service.dart:27-30

The service_role key — which bypasses every RLS policy — is embedded as a defaultValue string literal:
static const String defaultSupabaseServiceRoleKey = String.fromEnvironment(
  'SUPABASE_SERVICE_ROLE_KEY',
  defaultValue: 'eyJhbGciOi...swVBzLlo-fQ3xc1ezYD_VcPKElnTKa6ZyBMjeU1sjxM',
);
Anyone decompiling the APK extracts this key and gains full admin access to every tenant's data — queries bypass get_auth_tenant_id(), admin users API becomes fully exposed (adminFindUserByEmail, adminCreateUser, adminConfirmAndSetPassword), and all RLS protections become theatre.

Impact: Full data breach of every tenant in the system.
Fix: Delete the fallback. Move every service_role operation to the server bridge or a Supabase Edge Function. The mobile keeps only the anon key.

C-2. Plaintext passwords in SharedPreferences

File: lib/features/auth/presentation/screens/login_screen.dart:85-115

_recordRegisteredUserLocally serializes password: password.trim() into salesarmy_local_registered_users_v1. SharedPreferences on Android is a world-readable XML file inside the app sandbox; root access or a sideloaded forensic tool reads every user's password.

Fix: Switch to flutter_secure_storage (Android Keystore / iOS Keychain), or drop the local vault entirely and require Supabase.

C-3. Unverified OAuth deep-link scheme

File: android/app/src/main/AndroidManifest.xml:35-42

<intent-filter android:autoVerify="false">
  <data android:scheme="io.supabase.salesarmy" android:host="login-callback"/>
Any other installed app can register the same scheme and intercept the Supabase OAuth redirect — hijacking the auth code and session.

Fix: Move to Android App Links with android:autoVerify="true" over HTTPS, pointing at a .well-known/assetlinks.json on your domain.

---
🟠 High-Priority Findings

H-1. Notification realtime channel never unsubscribed on sign-out

File: lib/core/services/app_state.dart:2648-2660 (signOutSession)

_supabaseTenantChannel and _supabasePrinterOrdersChannel are correctly unsubscribed, but _notificationChannel opened at line 1251 is left connected. Every logout → login cycle stacks another live WebSocket.

H-2. Stale per-tenant cache keys never cleaned up

File: lib/core/services/app_state.dart:2704 (_clearSessionLocally)

Only session keys are removed. The 14 _prefsKey* entries (shops / products / orders / invoices / payments / ledger / visits / reminders / staff / purchases / expenses / bank accounts / notifications / liquid balances) remain on disk indefinitely under the previous tenant's prefix. Not a data leak (tenant-scoped keys protect isolation), but SharedPreferences grows unbounded on shared devices.

H-3. Monolithic AppState

File: lib/core/services/app_state.dart — 5,549 lines

336 call sites across the app depend on this single ChangeNotifier. Any change triggers rebuilds everywhere; testing is near-impossible; two developers cannot edit it in parallel without conflicts.

H-4. 10 screen files exceed 1,500 lines

3,323  profile_and_settings_screen.dart
3,235  distributor_dashboard.dart
2,533  inventory_tab.dart
2,325  hardware_settings_modal.dart
2,298  orders_tab.dart
1,914  collections_tab.dart
1,797  order_taker_flow.dart
1,734  estimated_bill_screen.dart
1,675  visits_tab.dart
Each should be decomposed into widget sub-trees + extracted dialogs.

H-5. Local-fallback auth undermines RLS trust boundary

File: lib/features/auth/data/services/auth_service.dart:248-310 (local vault + demo creds)

If Supabase is unreachable the user still authenticates locally — but has no JWT. The UI believes they're logged in; every subsequent Supabase query silently returns []. This is confusing UX and masks genuine auth failures.

---
🟡 Medium Findings

M-1. Clean Architecture applied inconsistently

Only inventory, orders, and shops have the full data / domain / presentation triad. The other 9 feature modules skip domain/. profile and reports have only presentation/ — no data layer at all.

M-2. Dead code guards

- collections_tab.dart:821 — if (false) block kept intentionally for a follow-up diff
- collect_payment_dialog.dart:739-900 — "live payment gateway dialog" marked for retire
- app_state.dart:1277 — _isTestEnvironment() unused

M-3. upsertUserProfile missing onConflict

File: supabase_service.dart:477 — relies on Supabase inferring the unique column.

M-4. "Expiring soon" subscription nudge not surfaced

AppState.isSubscriptionExpiringSoon and isTrialExpiringSoon are defined but no UI consumes them — the amber banner we added isn't being watched anywhere outside the dashboard, which may not re-evaluate between app resumes.

M-5. google_sign_in: ^6.2.2 dangling in pubspec

Not imported anywhere. Was removed when we switched to Supabase OAuth browser flow. Candidate for flutter pub remove.

M-6. Deprecated API uses

7 // ignore: deprecated_member_use directives — 6 clustered in payment_preferences_screen.dart (609–635), 1 in supabase_service.dart:74.

M-7. Thermal printer catalog is mock

printer_service.dart:30-71 ships 5 hard-coded fake devices (POS-58, Everycom, TVS, Epson, Sunmi). Real ESC/POS Bluetooth discovery is not wired through platform channels.

M-8. Test suite: 18 of 222 tests failing (92% pass)

Failures cluster in auth/RBAC flows, modal layout tests, invoice table scrolling, web admin sync. No skip:true tests — these are real regressions worth triaging.

---
🟢 Strengths

S-1. Tenant isolation is now correctly enforced

After the recent fixes:
- All 20 tenant_shree_ganesh_traders fallbacks removed (only remains in mock_data.dart:17 for tests)
- initForTenant hard-refuses empty tenantId/uid and triggers signOutSession()
- Every fetchShops / fetchProducts / fetchOrders / fetchInvoices / fetchPayments / fetchLedgerEntries chains .eq('tenant_id', tenantId) AND relies on server-side RLS via get_auth_tenant_id()
- SharedPreferences keys are tenant-scoped via _tenantStorageKey()

S-2. RPC-first write pattern

79 of 81 mutations go through RPCs with service-role-only grants: sync_save_order, record_payment, record_invoice, cancel_invoice, assign_user_role. Direct table writes are limited to tenant-safe .upsert() calls.

S-3. Robust offline outbox

lib/core/sync/outbox_manager.dart (172 lines):
- UUIDv4 mutation tokens for idempotency
- Exponential backoff: 10s × 2^retryCount, capped at 1 hour, max 10 retries
- Terminal-failure state after retries exhausted
- 7-day retention for committed mutations before pruning

S-4. Clean plan lifecycle semantics

isFreeTier correctly folds in _isSubscriptionEndDatePassed. Expired trials degrade to free-tier capability set via canAccessFeatureBySubscription. The Freemium Core Selling Guarantee (orders + kaccha bills always work) holds.

S-5. All core distributor workflows wire end-to-end

Flow: Order Taker → Complete & Bill → Order + Invoice
Coverage: ✅ both persist to Supabase + ledger entry
────────────────────────────────────────
Flow: Collections → Collect Payment (Cash / UPI / Razorpay) → ledger + balance
Coverage: ✅
────────────────────────────────────────
Flow: GST + Estimated (Kaccha) billing with 3-tier pricing
Coverage: ✅
────────────────────────────────────────
Flow: Add product with 3-tier variants + image
Coverage: ✅ wired to AppImageHelper.pickImageAsDataUri
────────────────────────────────────────
Flow: Staff add → per-module permissions (10 switches) → role-scoped MainShell tabs
Coverage: ✅

S-6. Dependencies are lean

Nothing abandoned. No HTTP client duplication. Only google_sign_in is a dead dep.

S-7. No TODO/FIXME debt

Zero // TODO: / // FIXME: / // HACK: markers in lib/ or test/.

---
Prioritized Remediation Roadmap

Week 1 — Security hardening (blockers for production)

1. C-1 Delete defaultSupabaseServiceRoleKey from supabase_service.dart. Move every call that used it (adminCreateUser, adminFindUserByEmail, adminConfirmAndSetPassword, direct table writes to tenants / products / shops) to the server bridge or an Edge Function.
2. C-2 Swap _recordRegisteredUserLocally to flutter_secure_storage. Better: drop the local vault entirely; make the app require Supabase auth.
3. C-3 Convert the Supabase OAuth deep link to an HTTPS App Link with assetlinks.json on your domain.

Week 2 — Lifecycle leaks

4. H-1 Add _notificationChannel?.unsubscribe() to signOutSession().
5. H-2 In _clearSessionLocally, iterate the 14 _prefsKey* constants and prefs.remove(_tenantStorageKey(key)).
6. H-5 Delete the local-vault / demo-password fallback paths from authenticateUser — fail cleanly to a "Please check your internet" state instead.

Weeks 3–6 — Architectural debt

7. H-3 Extract AppState into feature slices (TenantNotifier, OrderNotifier, BillingNotifier, CollectionsNotifier, InventoryNotifier). Target: no file above 1,500 LOC.
8. H-4 Split the 10 oversized screens — extract dialogs, card widgets, and per-tab bodies.
9. M-1 Backfill domain/ layers for auth, billing, collections, dashboard, admin.
10. M-4 Wire isSubscriptionExpiringSoon into the main shell app bar (persistent pill when ≤5 days left).

Ongoing

11. M-8 Triage the 18 failing tests — most are modal layout regressions that recent UI changes introduced.
12. M-5 / M-6 Clean up dangling google_sign_in dep and deprecated API calls.

---
Appendix — Inventory of Features & Their State

Feature: auth
Core screens: login, splash
Status: ✅ Complete
────────────────────────────────────────
Feature: orders
Core screens: order_taker_flow, orders_tab
Status: ✅ Complete, Clean Arch
────────────────────────────────────────
Feature: billing
Core screens: estimated_bill, gst_tax_invoice_viewer, reports
Status: ✅ Complete
────────────────────────────────────────
Feature: collections
Core screens: collections_tab, expense_screen
Status: ✅ Complete
────────────────────────────────────────
Feature: inventory
Core screens: inventory_tab, purchase_screen, record_purchase
Status: ✅ Complete, Clean Arch
────────────────────────────────────────
Feature: shops
Core screens: shops_tab, create_shop, shop_detail
Status: ✅ Complete, Clean Arch
────────────────────────────────────────
Feature: visits
Core screens: visits_tab, reminders_screen
Status: ✅ Complete
────────────────────────────────────────
Feature: dashboard
Core screens: distributor_dashboard, sales_data
Status: ✅ Complete
────────────────────────────────────────
Feature: reports
Core screens: sales, inventory, orders, ledger_graphical
Status: ✅ Complete
Feature: reports
Core screens: sales, inventory, orders, ledger_graphical
Status: ✅ Complete
────────────────────────────────────────
Feature: profile
Core screens: profile, profile_and_settings, gst_configuration, accounts
Status: ✅ Complete
────────────────────────────────────────
Feature: settings
Core screens: printer, hardware, payment_preferences, notifications, sync_and_backup
Status: ⚠️ Printer catalog is mock
────────────────────────────────────────
Feature: admin
Core screens: staff_management, plan_and_pricing, subscription_checkout, super_admin_console
Status: ⚠️ Super Admin console is partial stub

---
Bottom line: The business logic is in place and the core distributor workflows are shippable. The gating issue is not features — it's the three critical security items. Fix C-1, C-2, C-3 and this is a defensible beta. The architectural refactor (H-3, H-4) is urgent for long-term velocity but not a launch blocker.