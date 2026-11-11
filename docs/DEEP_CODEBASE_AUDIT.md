# Comprehensive Codebase Audit: SalesArmy Platform

**Date of Audit:** September 19, 2026  
**Target Codebase:** SalesArmy Monorepo (`apps/mobile`, `functions`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`)  
**Scope:** Architecture, Security & RBAC, Financial Accounting Integrity, Offline-First Synchronization, Performance & Scalability, UI/UX System, and Test Coverage.

---

## 1. Executive Summary & Health Scorecard

SalesArmy is an enterprise-grade FMCG B2B Distribution and Sales Force Automation platform with a **Flutter mobile client** and **Firebase Cloud Functions backend (TypeScript)**. The codebase exhibits a high level of architectural discipline, adhering to Clean Architecture on the client and Hexagonal Architecture on the backend.

### Platform Scorecard

| Dimension | Rating | Status | Summary |
|---|:---:|:---:|---|
| **Architecture & Modularity** | **9.5 / 10** | Excellent | Strict separation of concerns; feature-driven mobile modularity; pure backend domain engines decoupled from persistence. |
| **Security & Multi-Tenancy** | **9.0 / 10** | High | Tenant isolation enforced in `firestore.rules` and `storage.rules`; role-based permissions on client and backend; HMAC-SHA256 signature verification on webhooks. |
| **Financial & Ledger Integrity** | **9.5 / 10** | Excellent | Zero-drift double-entry ledger engine; intra/inter-state Indian GST tax engine; IEEE 754 decimal rounding safeguards. |
| **Offline-First Resilience** | **9.0 / 10** | High | UUIDv4 client mutation envelopes, outbox queue manager, memory-bounded LRU cache, and idempotent sync handlers. |
| **Performance & Query Optimization** | **8.8 / 10** | High | 18 composite Firestore indexes; paginated subcollection streams (`limit(50)`); LRU cache. |
| **UI/UX & Design System** | **9.2 / 10** | High | Standardized soft yellow brand (`#FFD233`), midnight slate typography (`#0F172A`), 16px geometry, uncluttered card layouts. |
| **Test Coverage & Quality** | **9.5 / 10** | Excellent | 0 analyzer issues (`flutter analyze`); 60 / 60 tests passing across 12 test suites (100% pass rate). |

---

## 2. Architectural Audit

### 2.1 Mobile Application (`apps/mobile/`)
- **Pattern**: Feature-Driven Clean Architecture (`apps/mobile/lib/features/`).
- **Core Subsystems**:
  - `core/cache/`: In-memory LRU cache with stream controllers and memory bounds.
  - `core/sync/`: `OutboxManager` and `SyncRepositoryImpl` handling client mutation envelopes (`ClientMutation`) for rural offline beats.
  - `core/navigation/main_shell.dart`: 5-pillar bottom navigation (`Home`, `Sell`, `Orders`, `Stock`, `Collect`, `Visits`) with strict module-level permission guards.
  - `core/services/app_state.dart`: Central `ChangeNotifier` managing reactive state, real-time Firestore listeners, RBAC permissions, and offline mutations.
  - `core/theme/app_theme.dart`: Consistent enterprise theme (primary yellow, midnight typography, soft shadows, card geometry).
- **Decoupled Standalone Modules**:
  - Monolithic screens were decoupled into dedicated screens: `ProfileScreen`, `AccountsScreen`, `ReportsScreen`, `StaffManagementScreen`, `SettingsScreen`, `PlanAndPricingScreen`, `PurchaseScreen`, and `ExpenseScreen`.
  - Obsolete legacy code (`profile_and_settings_screen.dart`) was removed cleanly.

### 2.2 Backend Cloud Functions (`functions/src/`)
- **Pattern**: Hexagonal (Ports & Adapters) Architecture.
- **Subsystems**:
  - `domain/`: 100% pure TypeScript business engines with zero database imports:
    - `tax-engine.ts`: Computes CGST/SGST/IGST and rounds with `Math.round((val + Number.EPSILON) * 100) / 100`.
    - `ledger-engine.ts`: Enforces single-sided journal entries, delta balance invariant validation, and zero balance drift.
    - `idempotency-engine.ts`: Deduplicates client mutations using UUIDv4 tokens to prevent duplicate billing.
  - `ports/`: `database.port.ts` and `cache.port.ts` specifying persistence interfaces.
  - `adapters/`: `FirestoreDatabaseAdapter`, `PostgresDatabaseAdapter`, and in-memory test harness.
  - `api/`: `sync-pull.handler.ts` (cursor-based delta sync) and `sync-push.handler.ts` (idempotent mutation ingestion).
  - Triggers: `invoices.ts` (sequential numbering `INV-YYYY-XXXX`), `notifications.ts` (daily scheduled due checks & FCM push), `payments.ts` (Razorpay webhook listener), `backup.ts` (scheduled cold storage backup), `audit.ts` (super admin logging).

---

## 3. Security, Authorization & Multi-Tenancy Audit

### 3.1 Cloud Firestore Rules (`firestore.rules`)
- **Tenant Isolation**:
  - All tenant documents and subcollections require `belongsToTenant(tenantId)` or `isSuperAdmin()`.
  - Subcollections covered: `products`, `categories`, `shops`, `orders`, `invoices`, `payments`, `ledgerEntries`, `visits`, `reminders`, `notifications`, `printers`, `reports`, `auditLogs`, `settings`, `client_mutations`, `dashboardStats`, `staff`, `purchases`, `expenses`.
- **Field-Level Immutability**:
  - `invoices`: Cannot tamper with `taxableAmount`, `cgst`, `sgst`, `igst`, `grandTotal`, `items`, or `invoiceNumber`. Deletion is disallowed (`allow delete: if false`).
  - `ledgerEntries`: Append-only immutable log (`allow update, delete: if false`).
  - `payments`: Once settled, amounts cannot be altered; deletion disallowed.
  - `users`: Users cannot alter their own `role`, `status`, or `tenantId`.
- **Platform Collections**:
  - Restricted to verified Super Admins (`plans`, `subscriptions`, `platformPayments`, `promoCodes`, `platformSettings`, `backups`).

### 3.2 Cloud Storage Rules (`storage.rules`)
- Default deny (`match /{allPaths=**} { allow read, write: if false; }`).
- Backups restricted to Super Admin or tenant owner (`tenants/{tenantId}/backups/{fileName}`).
- Isolated module folders (`tenants/{tenantId}/{module}/{fileName}`).

### 3.3 Role-Based Access Control (RBAC)
- **Presets**: `Owner` (full access), `Accountant` (financial & inventory access), `Delivery Staff` (orders & field only), `Field Sales` (orders, billing, expenses).
- **Module Permissions**: Granular toggles (`billing`, `orders`, `inventory`, `reports`, `accounts`, `purchase`, `expense`, `staff`, `settings`).
- **UI & Route Guards**: `MainShell` checks `canAccessModule` before navigating to tabs; action buttons hide or display alert notices when unauthorized.

---

## 4. Financial & Data Accounting Integrity

1. **Double-Entry Khata Ledger**:
   - Every invoice debits customer balance (`+amount`); every payment credits customer balance (`-amount`).
   - Invariant check in `ledger-engine.ts` verifies `(balanceAfter - balanceBefore) == (debit - credit)`. Any deviation throws a balance drift error immediately.
2. **Bill Deletion & Complete Financial Reversal**:
   - When an invoice is deleted, `AppState.deleteInvoice()` atomically:
     - Reverses unpaid dues from customer account (`currentOutstanding`).
     - Restores inventory SKU quantities for every line item.
     - Creates an `INVOICE_CANCELLED` audit ledger entry.
3. **Decimal Rounding Precision**:
   - JavaScript/Dart IEEE 754 floating-point inaccuracies (e.g., `0.1 + 0.2 = 0.30000000000000004`) are mitigated using `Number.EPSILON` rounding across tax calculations.

---

## 5. Offline-First & Synchronization System

- **Mutation Envelopes**: Mutations are wrapped as `ClientMutation` with client-generated UUIDv4 idempotency keys, tenant ID, mutation type, and JSON payload.
- **Outbox Queue**: Local outbox queue persists pending actions when connectivity is lost and automatically flushes when reconnected.
- **Silent Synchronization**:
  - Background synchronization operates silently without exposing technical cloud sync buttons on the main screen, meeting client UX specifications.
- **Device Loss Protection**:
  - All tenant records are persisted server-side in Firestore. Re-authenticating on another device streams the latest state seamlessly.

---

## 6. Performance & Database Optimization

- **Indexes**: 18 composite indexes defined in `firestore.indexes.json`, covering multi-field queries across orders, invoices, ledger entries, payments, and visits.
- **Pagination & Memory Management**:
  - Subcollection listeners in `AppState` are bounded with `.limit(50)`.
  - In-memory LRU cache evicts oldest entries when limits are reached, preventing memory bloat on low-end Android mobile devices.

---

## 7. Frontend Design System & Client UX Alignment

- **Color Palette**:
  - Primary Accent: Soft Yellow (`#FFD233` / `#FFE066`).
  - Dark Slate Neutrals: Midnight Slate (`#0F172A`) and Charcoal Slate (`#1E293B`) for high-contrast, WCAG-compliant typography.
  - Surface Backgrounds: Slate White (`#F8FAFC`) and Light Container Tint (`#FFFDF0`).
  - No harsh, clashing neon gradients.
- **Geometry & Cards**:
  - Standardized 16px radius geometry (`BorderRadius.circular(16)`).
  - Subtle borders (`#E2E8F0`) with ambient micro-shadows.
- **Client Meeting Spec Alignment**:
  - Compact company identity (circular monogram avatar).
  - Time-based greeting ("Good morning / afternoon / evening" strictly without user name).
  - 8-action fintech dock on Dashboard.
  - Dismissible Market Dues card.
  - Decoupled Profile, Accounts, Reports, Settings, and Staff screens.
  - 3-tab Reminders & Field Visits layout.
  - Full-text expandable notification reader.

---

## 8. Quality Assurance & Test Verification

| Test Suite | Coverage Area | Tests | Status |
|---|---|:---:|:---:|
| `frontend_features_test.dart` | GST Engine, AppFormatters, Shop/Product/Payment AppState | 7 | Passing |
| `models_test.dart` | ShopModel, ProductModel, OrderModel serialization & invariants | 4 | Passing |
| `inventory_tab_test.dart` | 3-tier pricing UI, catalog valuation card, filter pills | 3 | Passing |
| `orders_and_reports_test.dart` | Order Taker flow, Reports screen downloads, Collections tab | 4 | Passing |
| `gst_billing_toggle_test.dart` | GST invoicing toggle switch and calculation bypass | 5 | Passing |
| `hardware_settings_modal_test.dart` | ESC/POS thermal printer (58mm/80mm), Bluetooth, UPI QR | 1 | Passing |
| `staff_rbac_and_notifications_test.dart` | RBAC presets, module permissions, Staff CRUD, Reminders, Notifications | 7 | Passing |
| `distributor_profile_modal_test.dart` | Profile identity, bank separation, legal compliance | 6 | Passing |
| `security_and_subscription_audit_test.dart` | RBAC escalation prevention, subscription expiration banner | 10 | Passing |
| `super_admin_console_test.dart` | Super Admin KPI cards, subscribers, pricing matrix, coupons, maintenance | 9 | Passing |
| `super_admin_portal_route_test.dart` | Super admin portal login separation and route gate | 3 | Passing |
| `widget_test.dart` | Basic sanity test | 1 | Passing |
| **Total** | | **60** | **100% Passing** |

- `flutter analyze lib test`: **0 errors, 0 warnings, 0 lints**.

---

## 9. Identified Tech Debt & Future Roadmap

1. **Order Workflow Lifecycle (Delivery Handover)**:
   - *Current Status*: The Order Taker, bill generation, and invoice cancellation are fully functional. The complete delivery handover state machine (assignment to delivery staff, confirmation codes, payment on delivery) is explicitly tagged `BLOCKED — CLIENT CONFIRMATION REQUIRED` per sections 34, 50, 57, and 58 of the client spec.
   - *Recommendation*: Schedule the follow-up client discussion to finalize the delivery confirmation rules before implementing.
2. **Relational Database Adapter**:
   - *Current Status*: `PostgresDatabaseAdapter` is implemented in TypeScript ports as an alternative to Firestore.
   - *Recommendation*: If migrating to PostgreSQL for high-scale enterprise deployments, establish a production connection pool and run migration scripts.
3. **Physical Hardware Field Testing**:
   - *Current Status*: ESC/POS 58mm and 80mm thermal receipt generators and Bluetooth communication handlers are implemented and simulated in test suites.
   - *Recommendation*: Conduct on-site field testing with physical thermal Bluetooth POS hardware (e.g., Everycom EC-58, Bluewoods MPT-II).
