# Project Context

## Project Overview

**Project Name:** SalesArmy (Enterprise FMCG B2B Distribution, Field Sales Automation & Agency Operations Platform)  
**Target Platforms:** Android, iOS, Web (Flutter Mobile/Tablet), Web Admin Portal (HTML5/CSS3/ES6 Standalone SPA on Node.js Port 3000), Firebase Cloud Functions (Node.js/TypeScript), and Supabase (PostgreSQL 15+, Auth, Storage & Realtime Channels).  
**Primary Domain:** Fast-Moving Consumer Goods (FMCG) Distribution, Field Sales Force Automation (SFA), Van Sales & Delivery, B2B Retail Khata Ledger, GST Tax Invoicing & Kaccha/Estimated Billing, Hardware Thermal POS Printing, and Multi-Tenant SaaS Administration.

### Core Objectives
1. **Field Force Empowerment & Beat Coverage**: Enable field sales agents to execute retail store visits, take instant catalog orders, capture GPS check-ins, record field returns with automatic inventory restock, and collect outstanding dues with cash, dynamic UPI QR, or payment gateways.
2. **GST Invoicing & Kaccha / Estimated Thermal Billing**: Generate compliant Indian GST tax invoices (CGST, SGST, IGST) or informal non-taxable proforma estimates ("Kaccha Bills") with on-the-spot thermal Bluetooth printing (58mm/80mm ESC/POS) and WhatsApp/PDF sharing.
3. **Zero-Drift Double-Entry Accounting**: Guarantee mathematical ledger integrity with strict debits/credits, automated dues deduction, balance reconciliation, in-hand cash tracking, and comprehensive Khata statements.
4. **Offline-First Resilience**: Operate seamlessly in rural and low-connectivity retail clusters via an offline mutation queue (Outbox), memory-bounded LRU caches, and idempotent synchronization.
5. **Multi-Tenant SaaS Governance & Express Checkout**: Provide dedicated Super Admin controls (Mobile Console & Web Admin Portal) for tenant lifecycle management, express subscription checkouts with optional POS hardware printer bundling, promo coupons, and hardware fulfillment logistics.
6. **Dual Backend & Real-Time Web Admin Interoperability**: Support seamless bidirectional synchronization between the Flutter mobile application, the standalone Web Admin Portal via a zero-dependency HTTP & Server-Sent Events (SSE) bridge server, Firebase Cloud Functions, and Supabase PostgreSQL backend.
7. **Client Specification Alignment**: Strict realization of all 27 operational principles outlined in `docs/CLIENT_MEETING_SPEC.md` (clean card-based presentation, circular company monogram avatar, separation of profile identity from accounts/banking, consolidated reports hub, simplified purchase and expense tracking, granular staff RBAC module permissions, time-based greetings, dismissible daily operational alerts, high-frequency action dashboard).

### User Types and Roles
- **Field Sales Executive / Salesman**: Visits assigned retailer beats, collects orders, prints estimated/tax bills, records daily expenses, and logs store visit remarks. Shell navigation dynamically isolates sales tools (`Home`, `Parties`, `Orders`).
- **Van Delivery Agent**: Dispatched order delivery, customer address lookup, and status updates. Shell navigation strictly exposes delivery tools (`Home`, `Orders`).
- **Accountant**: Manages company finances, billing, Khata collections, daily expense audits, and financial reporting. Shell navigation exposes financial tools (`Home`, `Parties`, `Bill`, `Collection`).
- **Store / Warehouse Manager**: Oversees stock inward purchases, inventory valuation, and warehouse orders (`Home`, `Parties`, `Orders`).
- **Distributor / Agency Owner (Tenant Admin)**: Full administrative authority over agency settings, pricing tiers, staff directory, banking profiles, multi-format reports, and subscription renewals (`Home`, `Parties`, `Bill`, `Orders`, `Collection`).
- **SaaS Super Admin (Platform Owner)**: Global platform governance via both Mobile Super Admin Console and Web Admin Portal (`apps/web-admin/`), monitoring tenant GMV/MRR, configuring SaaS pricing tiers, hardware printer bundling, remote feature kill-switches, and emergency announcements.

---

## Tech Stack

| Layer | Technology | Version / Notes |
|---|---|---|
| **Frontend Mobile Framework** | Flutter / Dart | Flutter 3.47+ / Dart 3.13+ (Android, iOS, Web) |
| **Mobile Architecture** | Clean Architecture + Monorepo | Feature-driven modular layout (`apps/mobile/lib/features/`) |
| **Mobile State Management** | Provider (`ChangeNotifier`) | Central `AppState` with reactive listeners and stream controllers |
| **Theme & UI System** | Light & Dark Mode Engine | Dual-theme system in `AppTheme`, persistent preference, WCAG contrast |
| **Image & Media Handling** | Image Picker + Custom Helper | `AppImageHelper` camera/gallery capture, local vs network resolution |
| **Local Cache & Outbox** | In-Memory LRU Cache + Outbox | Memory-bounded LRU cache with stream controllers, UUIDv4 outbox mutations |
| **Hardware & Peripherals** | ESC/POS Thermal Bluetooth | 58mm (2-inch) and 80mm (3-inch) wireless thermal receipt printers |
| **Web Admin Portal** | HTML5 / CSS3 / ES6 JavaScript | Standalone Super Admin SPA (`apps/web-admin/`) with glassmorphic UI |
| **Web Admin Interop Bridge** | Node.js HTTP & SSE Server | Port 3000 zero-dependency server (`server.js`) with Server-Sent Events |
| **Relational Database & Auth** | Supabase (PostgreSQL 15+) | `supabase_flutter 2.8.0`, Auth, Realtime Channels, 17 relational tables |
| **NoSQL Cloud Database** | Google Cloud Firestore | Multi-tenant NoSQL document store with 18 composite indexes |
| **Backend Runtime** | Firebase Cloud Functions | Node.js 18+ with TypeScript 5.x |
| **Backend Architecture** | Hexagonal Architecture | Pure domain engines decoupled from ports and database adapters |
| **Payment Gateway** | Razorpay / UPI / BharatQR / Cash | Dynamic UPI intent QR generation, Cash tracking, and Razorpay webhooks |
| **Build & Monorepo Tooling** | Melos / Gradle / npm | Melos workspace (`apps/mobile`, `apps/web-admin`, `functions/`, `packages/`, `tools/`), Gradle 8.14 |
| **Testing Framework** | Flutter Test / Node Harness | 42 comprehensive test suites, 200+ unit and widget assertions |

---

## Architecture

### High-Level System Architecture

```
┌──────────────────────────────────────┐        ┌──────────────────────────────────────┐
│     Flutter Mobile / Tablet App      │        │        Web Admin Portal (SPA)        │
│   (Android, iOS, Web - Clean Arc)    │        │    (HTML5, CSS3, ES6 JavaScript)     │
└──────────────────┬───────────────────┘        └──────────────────┬───────────────────┘
                   │                                               │
                   │    REST / SSE Sync (Port 3000 / 10.0.2.2)     │
                   ├───────────────────────────────────────────────┤
                   │                                               ▼
                   │                               ┌───────────────────────────────────┐
                   │                               │    Web Admin & Interop Bridge     │
                   │                               │   (Node.js server.js on :3000)    │
                   │                               │   • SSE Real-Time Stream Engine   │
                   │                               │   • PostgREST Direct Synchronizer │
                   │                               │   • Printer Orders Pipeline       │
                   │                               │   • Platform State Persistence    │
                   │                               └─────────────────┬─────────────────┘
                   │                                                 │
                   ├───────────────────────────────┐                 │ PostgREST / Auth API
                   ▼                               ▼                 ▼
┌──────────────────────────────────────┐        ┌──────────────────────────────────────┐
│  Firebase Cloud Functions & NoSQL    │        │       Supabase Backend Platform      │
│                                      │        │                                      │
│ • Hexagonal Domain Engines           │        │ • PostgreSQL 15+ Relational Store    │
│   (TaxEngine, LedgerEngine, Idempot) │        │ • Multi-Tenant Row Level Security    │
│ • Cloud Firestore Document Store     │        │ • Supabase Auth & JWT Claims         │
│ • Razorpay Webhook Settlements       │        │ • Realtime Broadcast Channels        │
│ • Automated Scheduled Backups        │        │ • Platform Settings Synchronization  │
└──────────────────────────────────────┘        └──────────────────────────────────────┘
```

### Key Architectural Patterns
1. **Monorepo Structure**: Complete separation of mobile application (`apps/mobile`), web-based super admin panel (`apps/web-admin`), cloud functions (`functions/`), supabase database definitions (`supabase/`), shared packages (`packages/`), and developer automation tools (`tools/`).
2. **Clean Architecture (Mobile Client)**: Feature modules (`admin`, `auth`, `billing`, `collections`, `dashboard`, `inventory`, `orders`, `profile`, `reports`, `settings`, `shops`, `visits`) feature decoupled data, domain, and presentation layers.
3. **Hexagonal Architecture (Cloud Backend)**: Pure TypeScript domain engines in `functions/src/domain/` with zero database dependencies, isolated behind ports (`ports/database.port.ts`).
4. **Offline-First Outbox Pattern**: Client mutations wrapped in `ClientMutation` envelopes with UUIDv4 idempotency tokens, written to a persistent queue, executed immediately against local cache, and drained asynchronously to the cloud.
5. **Dynamic Role-Based Shell Tabs**: Instead of displaying static or locked tabs, `MainShell` dynamically queries active role capabilities (`_buildAvailableTabs(appState)`) to assemble only role-authorized navigation pills.
6. **Dual-Backend Synchronization**: Mobile clients seamlessly integrate with both Firebase Firestore and Supabase PostgreSQL (`SupabaseService`), providing resilient fallbacks, realtime notifications, and cloud scalability.
7. **Real-Time Bidirectional Web Admin Interoperability**: `AppState` connects to the local admin bridge (`10.0.2.2:3000` / `localhost:3000`), synchronizing subscription plans, printer options, promo coupons, remote kill-switches, and broadcast banners in real time.

---

## Folder Structure

```text
sales_army/
├── .github/workflows/ci.yml           # Automated CI workflow
├── firebase.json                      # Firebase project configuration
├── firestore.rules                    # Cloud Firestore tenant isolation & security rules
├── firestore.indexes.json             # 18 composite database indexes
├── storage.rules                      # Cloud Storage security rules
├── melos.yaml                         # Monorepo workspace configuration
├── docs/
│   ├── CLIENT_MEETING_SPEC.md         # Comprehensive 27-section client specification
│   ├── DEVELOPMENT_AUDIT.md           # Chronological development milestones
│   └── DEEP_CODEBASE_AUDIT.md         # Comprehensive structural health audit
├── PROJECT_CONTEXT.md                 # Single-source-of-truth project memory & knowledge base
├── supabase/                          # Supabase PostgreSQL schema & migration scripts
│   ├── COMPLETE_SUPABASE_SETUP.sql    # Complete standalone enterprise SQL setup script
│   └── migrations/
│       ├── 20261012000000_init_salesarmy_schema.sql
│       └── 20261012000001_supabase_rbac_and_auth.sql
├── apps/
│   ├── mobile/                        # Flutter Mobile & Tablet Application
│   │   ├── pubspec.yaml               # Flutter dependencies (Provider, Supabase, Image Picker, etc.)
│   │   ├── android/                   # Android native platform project (AGP 8.11+, Gradle 8.14)
│   │   ├── ios/                       # iOS native platform project
│   │   ├── web/                       # Web entry points and assets
│   │   ├── assets/                    # Brand logos (SalesArmy Logo 1, 2, Black, SVGs)
│   │   ├── test/                      # 42 unit and widget test suites (200+ test assertions)
│   │   └── lib/
│   │       ├── main.dart              # Application entry point with dual theme & Supabase init
│   │       ├── firebase_options.dart  # Multi-platform Firebase credentials
│   │       ├── core/                  # Cross-cutting core services
│   │       │   ├── cache/             # Memory-bounded LRU caches
│   │       │   ├── navigation/        # Dynamic role-based MainShell navigation
│   │       │   ├── network/           # Connectivity & HTTP client wrappers
│   │       │   ├── services/          # AppState, SupabaseService, NotificationService, MockData
│   │       │   ├── sync/              # OutboxManager, sync entities & repositories
│   │       │   ├── theme/             # AppTheme (Light & Dark theme palettes, typography)
│   │       │   ├── utils/             # AppFormatters, AppImageHelper, FeatureGate, CsvReportHelper
│   │       │   └── widgets/           # BouncingWidget, UI helpers
│   │       └── features/              # Feature modules
│   │           ├── admin/             # Super Admin console, Express Checkout, Staff management
│   │           │   ├── data/          # CouponModel, PrinterOptionModel, StaffModel, SubscriptionPlanModel, TenantModel
│   │           │   └── presentation/  # PlanAndPricingScreen, SubscriptionCheckoutScreen, SuperAdminConsole
│   │           ├── auth/              # LoginScreen (3-tab segmented), SplashScreen, AuthService
│   │           ├── billing/           # GST Invoice viewer, EstimatedBillScreen (Kaccha Bill), ReportsScreen
│   │           ├── collections/       # Payment collection dialogs, ExpenseScreen, CollectionsTab
│   │           ├── dashboard/         # DistributorDashboard, SalesDataScreen, NotificationCenterModal
│   │           ├── inventory/         # InventoryTab, PurchaseScreen, RecordPurchaseScreen, 3-tier pricing
│   │           ├── orders/            # OrderTakerFlow, OrdersTab, SalesReturnDialog, SalesReturnModel
│   │           ├── profile/           # ProfileScreen, AccountsScreen, GstConfigurationScreen, ProfileAndSettingsScreen
│   │           ├── reports/           # Dedicated analytical reporting screens
│   │           │   └── presentation/screens/
│   │           │       ├── inventory_report_screen.dart
│   │           │       ├── ledger_graphical_report_screen.dart
│   │           │       ├── orders_report_screen.dart
│   │           │       └── sales_report_screen.dart
│   │           ├── settings/          # PrinterSettingsScreen, PaymentPreferencesScreen, NotificationsScreen, HardwareSettingsScreen
│   │           ├── shops/             # ShopsTab (Parties), CreateShopScreen, ShopDetailScreen
│   │           └── visits/            # VisitsTab (Reminders & Field Visits), RemindersScreen
│   └── web-admin/                     # Standalone Super Admin Web Portal & Interop Server
│       ├── README.md                  # Web Admin documentation & setup guide
│       ├── index.html                 # Modern glassmorphism SPA dashboard
│       ├── app.js                     # Web portal application logic & state bindings
│       ├── styles.css                 # Responsive stylesheet with dark/glass themes
│       ├── server.js                  # Zero-dependency Node.js HTTP & SSE server (:3000)
│       ├── legal.html                 # Legal, Privacy Policy, Terms & Compliance portal
│       ├── package.json               # Package definition and npm scripts
│       ├── scripts/                   # Automated E2E verification test scripts
│       │   ├── test_admin_portal_e2e.js
│       │   ├── test_live_db_sync.js
│       │   └── test_postgrest.js
│       └── data/
│           └── platform_state.json    # File-backed platform state & order repository
├── functions/                         # Firebase Cloud Functions (TypeScript)
│   ├── package.json                   # Node dependencies
│   ├── tsconfig.json                  # TypeScript compiler configuration
│   └── src/
│       ├── index.ts                   # Exported Cloud Function triggers
│       ├── audit.ts                   # Super admin audit logging
│       ├── backup.ts                  # Scheduled tenant backup job
│       ├── dashboard.ts               # Aggregation metrics
│       ├── invoices.ts                # Auto-invoice numbering triggers
│       ├── notifications.ts           # Cloud messaging triggers
│       ├── payments.ts                # Razorpay webhook and payment settlement
│       ├── adapters/                  # Firestore, PostgreSQL, and Memory adapters
│       ├── api/                       # Sync push/pull handlers & auth middleware
│       ├── domain/                    # TaxEngine, LedgerEngine, IdempotencyEngine
│       └── ports/                     # Database & Cache interface ports
├── packages/                          # Shared reusable packages
└── tools/                             # Automation scripts & tooling
    └── scripts/update_imports.js
```

---

## Frontend System

### Navigation & Dynamic Role Shell Hierarchy
- **`MainShell` (`apps/mobile/lib/core/navigation/main_shell.dart`)**:
  - **Dynamic Tab Assembly (`_buildAvailableTabs`)**:
    - **Owner / Distributor Admin**: `Home`, `Parties`, `Bill`, `Orders`, `Collection` (Full 5-pillar access).
    - **Accountant**: `Home`, `Parties`, `Bill`, `Collection` (Orders omitted).
    - **Field Sales Executive**: `Home`, `Parties`, `Orders` (Bill and Collection omitted; takes orders via Order Taker).
    - **Delivery Agent**: `Home`, `Orders` (Parties, Bill, Collection omitted).
    - **Store Manager**: `Home`, `Parties`, `Orders`.
  - **App Bar**:
    - Top-Left: Circular Company Monogram / Logo Avatar (`_getInitials(firmName)`) and Firm Name; tap navigates directly to `ProfileAndSettingsScreen(initialTab: 0)`.
    - Center: Prominently centered "Sales Army" brand badge with signature yellow accent (`#FFD233`).
    - Top-Right: Notification Bell with unread micro red beacon indicator (opens `NotificationCenterModal`). Technical manual cloud sync buttons removed in favor of **Silent Background Sync**.
  - **Tab Switching Engine**:
    - Supported tab IDs: `home`, `shops`, `billing`, `orders`, `collections`.
    - Full backward compatibility with integer indices (`_navigateToLegacyTab`).

### Screen & Modal Inventory

#### Feature: Admin & Platform Governance (`features/admin/`)
- **`PlanAndPricingScreen`**: Active subscription card, renewal countdown, plan feature matrix, printer hardware rates, and direct transition to Express Checkout.
- **`SubscriptionCheckoutScreen`**: Express subscription checkout flow supporting monthly/annual billing toggles, optional Bluetooth POS thermal printer hardware bundling, coupon code redemption, and real-time GST computation.
- **`StaffManagementScreen`**: Staff directory with role presets (`Owner`, `Sales Rep`, `Accountant`, `Delivery Boy`, `Store Manager`), granular permission switches, and instant role simulation.
- **`SuperAdminConsole`**: Platform-wide portal featuring 5 tabs: `Dashboard` (GMV/MRR KPIs), `Features` (Remote feature kill-switches, SMS gateway config, emergency broadcast), `Plans` (SaaS pricing matrix & printer options), `Subscribers` (Tenant directory & freemium overrides), and `Settings` (Maintenance mode, backups).
- **`SuperAdminLoginScreen`**: Dedicated gate requiring super admin master credentials.

#### Feature: Authentication & Onboarding (`features/auth/`)
- **`LoginScreen`**: Modern 3-tab segmented control (`Owner / Distributor`, `Staff Member`, `Super Admin Console`), dynamic role capability previews, instant 1-tap demo credentials for quick inspection, agency code inputs for staff, and Supabase Auth integration.
- **`SplashScreen`**: Branded startup animation displaying official SalesArmy logo, auto-initializing Supabase and local cache, and routing intelligently to `MainShell` or `LoginScreen`.

#### Feature: Billing & Invoicing (`features/billing/`)
- **`GstTaxInvoiceViewer`**: Print-ready thermal (58mm/80mm) and A4 invoice viewer with tax breakdown (CGST, SGST, IGST), number-to-words currency formatting, bill deletion, and WhatsApp/PDF sharing.
- **`EstimatedBillScreen`**: Full-screen viewer for informal non-taxable "Kaccha Bills" / estimates with 58mm/80mm thermal Bluetooth print, WhatsApp sharing, and dues adjustment.
- **`ReportsScreen`**: Consolidated financial reports hub offering 1-click downloads for GST Tax Invoices, period statements, and Khata ledger exports with CSV and WhatsApp sharing.

#### Feature: Orders & Returns (`features/orders/`)
- **`OrderTakerFlow`**: High-speed mobile POS order taker with instant search, category pills, wholesale/retail margin indicators, quantity steppers, and order completion modal.
- **`OrdersTab`**: Sub-tabs for active/completed orders, GST tax invoices, and estimated bills with standalone order deletion and quick billing conversions.
- **`SalesReturnDialog`**: Comprehensive return dialog handling line-item returns, selectable return reasons (Damage, Expiry, Excess), automatic inventory restock, and Khata credit adjustments.

#### Feature: Inventory & Purchases (`features/inventory/`)
- **`InventoryTab`**: SKU valuation card, stock counts, 3-tier pricing cards (Wholesale, Retail, Customer/MRP), category filters, and circular `+` FAB.
- **`PurchaseScreen`**: Non-accounting stock inward log for supplier bills, tracking bill numbers, item counts, landed costs, and credit/paid status.
- **`RecordPurchaseScreen`**: Form to record incoming inventory lots with supplier details.

#### Feature: Collections & Khata Ledger (`features/collections/`)
- **`CollectionsTab`**: Market outstanding balance, payment collection drawer, Khata books, and daily expense tracker link.
- **`CollectPaymentDialog`**: Split payment selector (Cash, UPI QR, Razorpay), reference entry, and atomic dues reconciliation.
- **`ExpenseScreen`**: Daily field expenditure tracker with quick categories (Fuel, Food/Allowance, Vehicle Repair, Loading/Unloading, Misc) and daily totals.
- **`LedgerReportModal`**: Multi-period statement generator (This Month, Quarter, Financial Year) with CSV/Excel export and WhatsApp share formatting.

#### Feature: Dedicated Reporting Hub (`features/reports/`)
- **`InventoryReportScreen`**: Valuation breakdown, reorder alerts, dead-stock analysis.
- **`LedgerGraphicalReportScreen`**: Visual dues trendlines, aging analysis of market dues.
- **`OrdersReportScreen`**: Order status breakdown, fulfillment velocity metrics.
- **`SalesReportScreen`**: Turnover trends, revenue by beat/route and salesperson.

#### Feature: Settings & Hardware (`features/settings/`)
- **`PrinterSettingsScreen`**: ESC/POS thermal printer configuration (58mm / 80mm paper width), Bluetooth auto-connect, receipt footer text, and test print triggers.
- **`PaymentPreferencesScreen`**: Multiple bank account management (strictly validated against max account limits), UPI VPA setup, and dynamic BharatQR generator.
- **`NotificationsScreen`**: Push notifications and SMS alert configuration.
- **`SyncAndBackupScreen`**: Data coverage metrics, scheduled auto-backup configuration (Weekly/Monthly), and instant JSON export.

#### Feature: Profile & Legal (`features/profile/`)
- **`ProfileAndSettingsScreen`**: Consolidated 2-segment controller combining Profile & Legal with Settings & Hardware. Camera and gallery photo picker integration via `AppImageHelper`.
- **`GstConfigurationScreen`**: Custom GST slabs configuration and invoice tax rules.
- **`DistributorProfileModal`**: Quick edit modal for firm name, GSTIN, PAN, and address.
- **`ResetAccountDialog`**: Safety modal requiring confirmation phrase (`RESET-MY-ACCOUNT`) before resetting transaction logs while retaining catalog products.

#### Feature: Dashboard & Reminders (`features/dashboard/`, `features/visits/`)
- **`DistributorDashboard`**: Executive financial slate featuring In-Hand Cash card, Turnover progress, curated 8-action fintech dock, dismissible Market Dues card, and dismissible daily reminder cards.
- **`SalesDataScreen`**: Deep-dive analytics on daily sales, average order value, and collection velocity.
- **`VisitsTab`**: 3-tab layout: `Upcoming Visits`, `Completed Visits`, and `Reminders & Tasks`.
- **`NotificationCenterModal`**: Full-text expandable notification reader with unread counter badge.
- **`NotificationService`**: Real-time push notification listener, top slide-in interactive popup banners with auto-dismiss and haptic feedback.

### Theme & Styling Standard
- **Dual Theme Support (Light & Dark Mode)**:
  - Persistent state controlled via `AppState.isDarkMode` and `SharedPreferences`.
  - **Light Theme**: Executive Royal Blue (`Color(0xFF1E56E2)`), Slate canvas (`Color(0xFFF8FAFC)`), and crisp white containers (`Color(0xFFFFFFFF)`).
  - **Dark Theme**: Midnight Slate background (`Color(0xFF0F172A)`), Charcoal card surface (`Color(0xFF1E293B)`), Light blue accent (`Color(0xFF60A5FA)`), and crisp white typography.
- **Signature Yellow Brand Accents**: Warm yellow primary (`Color(0xFFFFD233)` / `Color(0xFFFFCC00)`) preserved as active indicators, brand badges, and primary action CTAs.
- **Geometry & Cards**: Standardized 16px to 20px rounded corners (`BorderRadius.circular(16)`), subtle 1px slate borders (`#E2E8F0` / `#334155`), and ambient soft micro-shadows (`AppTheme.softShadow`).
- **Floating Action Buttons**: Strictly formatted with circular geometry (`shape: BoxShape.circle` / `CircleBorder()`) across Inventory and Orders tabs.

---

## Web-Based Admin Panel & Bridge Server (`apps/web-admin/`)

### Overview & Purpose
A dedicated, standalone Web Super Admin Portal decoupled from Flutter, providing SaaS administrators with full desktop control over subscriptions, coupons, pricing plans, hardware fulfillment, remote feature kill-switches, and broadcast banners.

### Architecture & Interoperability Bridge (`server.js`)
- Runs a zero-dependency Node.js HTTP server on **Port 3000**.
- Serves the static single-page application (`index.html`, `app.js`, `styles.css`, `legal.html`).
- Hosts an HTTP & Server-Sent Events (SSE) bridge accessible by both the browser and the mobile app:
  - Local browser: `http://localhost:3000`
  - Android Emulator: `http://10.0.2.2:3000`
- Persists state changes directly to `apps/web-admin/data/platform_state.json`.
- Integrates directly with Supabase via PostgREST and Auth API helpers (`postgrestRequest`, `supabaseAuthRequest`).

### Bridge REST Endpoints & SSE Streaming

| Endpoint | Method | Description |
|---|---|---|
| `/api/platform/all` | `GET` | Returns full platform state (plans, printer options, coupons, tenants, users, remote config, broadcast, printer orders). |
| `/api/platform/events` | `GET` | Real-time Server-Sent Events (SSE) stream broadcasting state updates, new hardware orders, and user syncs. |
| `/api/platform/update` | `POST` | Merges or overwrites platform configuration and broadcasts updates to connected SSE clients. |
| `/api/platform/order-hardware` | `POST` | Enqueues a new POS Bluetooth printer order from the mobile Express Checkout flow. |
| `/api/platform/sync-tenant` | `POST` | Updates tenant subscription status, active plan ID, or billing details. |
| `/api/platform/sync-user` | `POST` | Creates or updates user directory records. |
| `/api/platform/user/:id` | `DELETE` | Deletes a user from the platform directory. |

### Core Admin Modules
1. **Promo & Membership Trial Coupons**:
   - Create coupons with auto-generated or custom codes (e.g. `TRIAL30`, `FLAT100`, `SAVE50`, `DEMO1DAY`).
   - Types: `trial` (free premium membership days), `flat` (rupee deduction), `percent` (percentage off).
   - Usage caps (`maxUses`), minimum order value thresholds, and 1-click active/paused toggles.
2. **Pricing Plans & Hardware Bundling Configuration**:
   - Tiers: Startup (₹399/mo, ₹3,828/yr), Grow (₹599/mo, ₹5,748/yr), Enterprise (₹899/mo, ₹8,628/yr).
   - Printer hardware pricing and GST tax rates (18%).
3. **Hardware Printer Fulfillment Pipeline**:
   - Tracks incoming orders from mobile checkout (`Pending` -> `In Transit` -> `Delivered`).
   - Assigns courier names (BlueDart, DTDC, Delhivery) and tracking AWB numbers.
4. **Tenant & User Directory**:
   - Unique User IDs (`SA-USR-XXXX`), firm names, subscription status (`active`, `trial`, `freemium`, `suspended`).
   - **Freemium Core Selling Guarantee**: Explicitly verifies that non-subscribed tenants retain full access to order creation and billing.
5. **Remote App Governance & Emergency Broadcasts**:
   - Maintenance mode switch with custom message and ETA.
   - Remote feature kill-switches (`order_taking`, `gst_invoicing`, `collections`, `gps_tracking`, `thermal_printer`, `soundbox_audio`, `staff_management`, `van_stock`, `customer_portal`, `instant_sync`, `purchases`, `expenses`, `reports`).
   - Live emergency broadcast banner with severity levels (`info`, `warning`, `critical`).

---

## Dual-Backend Architecture (Firebase & Supabase)

### 1. Hexagonal Domain Engines (Firebase Functions)
- **`TaxEngine` (`functions/src/domain/tax-engine.ts`)**: Computes GST for intra-state (equal CGST + SGST split) and inter-state (IGST) transactions.
- **`LedgerEngine` (`functions/src/domain/ledger-engine.ts`)**: Pure double-entry accounting engine maintaining strict single-sided journal entries with zero-drift balance validation: `(balanceAfter - balanceBefore) === (debit - credit)`.
- **`IdempotencyEngine` (`functions/src/domain/idempotency-engine.ts`)**: Deduplicates incoming client mutations using client-generated UUIDv4 mutation tokens.

### 2. Cloud Function Triggers & Endpoints
- **`syncPullHandler` (`functions/src/api/sync-pull.handler.ts`)**: Delta synchronization endpoint supporting timestamp cursor pagination.
- **`syncPushHandler` (`functions/src/api/sync-push.handler.ts`)**: Ingests batched client mutations with atomic validation.
- **`handleRazorpayWebhook` (`functions/src/payments.ts`)**: Secure webhook listener validating HMAC-SHA256 signatures, automatically marking invoices as paid, and creating ledger entries.
- **`onInvoiceCreate` (`functions/src/invoices.ts`)**: Firestore trigger assigning sequential invoice numbers per tenant (`INV-YYYY-XXXX`).
- **`triggerScheduledBackup` (`functions/src/backup.ts`)**: Automated cron task backing up tenant data into isolated cold storage.
- **`sendDuePaymentNotifications` (`functions/src/notifications.ts`)**: Daily scheduled job checking overdue retailer balances and triggering FCM push notifications.

### 3. Supabase Relational Schema (`supabase/`)
The platform supports a production-grade PostgreSQL 15+ backend architecture:
- **`tenants`**: Multi-tenant agencies with business info, GSTIN, PAN, bank accounts, plan ID, subscription dates, and active status.
- **`profiles`**: Linked to `auth.users(id)` with RBAC roles (`super_admin`, `owner`, `distributor`, `accountant`, `sales_person`, `delivery_agent`, `manager`).
- **`categories`** & **`products`**: Multi-tier pricing (Wholesale, Retail, Customer/MRP), HSN/SAC codes, stock quantities, and low stock alert thresholds.
- **`shops`**: Retail store directory, geolocation (`latitude`, `longitude`), credit limits, and real-time outstanding dues (`current_outstanding`).
- **`orders`** & **`order_items`**: Dispatched orders, line items, rates, GST amounts, and delivery notes.
- **`invoices`**: Tax and estimate invoices, seller/buyer snapshots, CGST, SGST, IGST totals, and payment status (`paid`, `partial`, `unpaid`).
- **`ledger_entries`**: Immutable double-entry bookkeeping journal entries.
- **`payments`**: Payment transactions (Cash, UPI, Razorpay) with reference numbers and timestamps.
- **`purchases`**: Stock inward purchase records.
- **`expenses`**: Field operational expenses categorized by type.
- **`visits`** & **`reminders`**: Beat routes, scheduled visits, and follow-up tasks.
- **`printer_hardware_orders`**: POS thermal printer orders enqueued from mobile express checkout.
- **`platform_settings`**: Key-value JSONB settings (`pricing_and_plans`, `remote_config`, `broadcast`) synced in real-time with Web Admin.
- **`notifications`**: Targeted user/role push notifications with Supabase Realtime broadcast channels.
- **Row Level Security (RLS)**: Enforces tenant boundaries via `tenant_id = auth.jwt() ->> 'tenant_id'`, protects ledger immutability, and grants super admins global read/write access.

---

## Authentication & Authorization

- **Authentication Providers**: Firebase Authentication and Supabase Auth (Email & Password).
- **Tenant Context**: Upon login, user claims and tenant profile documents hydrate `tenantId`, `role` (`owner`, `distributor`, `salesman`, `delivery`, `accountant`, `manager`, `super_admin`), and active module permissions.
- **Dynamic RBAC Module Permissions**:
  - `billing`: Access to Order Taker billing and invoice generation.
  - `orders`: Access to dispatch order lists.
  - `shops`: Access to retail customer directory.
  - `inventory`: Access to SKU catalog and 3-tier price edits.
  - `reports`: Access to analytical reporting suites.
  - `accounts` / `collections`: Access to Khata ledgers, payment collection drawer, and bank preferences.
  - `purchase`: Access to stock inward logging.
  - `expense`: Access to field expense logs.
  - `staff`: Access to staff directory and permission configuration.
  - `settings`: Access to hardware, printer, and payment setup.
- **Freemium Core Selling Policy**:
  - Non-subscribed or expired accounts are never blocked from core distribution tasks (order taking, estimated bills, retail visits, and cash collections).

---

## API Routes

### Cloud Functions REST Endpoints
| Endpoint | Method | Auth | Description |
|---|---|---|---|
| `/api/sync/pull` | `POST` | Bearer Token | Delta sync cursor query retrieving updated records across all collections. |
| `/api/sync/push` | `POST` | Bearer Token | Ingests a batch of offline client mutations with idempotency deduplication. |
| `/api/payments/razorpay-webhook` | `POST` | Webhook Signature | Verifies HMAC-SHA256 signature and settles invoices automatically. |
| `/api/dashboard/summary` | `GET` | Bearer Token | Aggregates distributor sales, pending dues, and active orders. |
| `/api/admin/tenants` | `GET/POST` | Super Admin | Lists and creates tenant enterprise subscriptions. |

### Web Admin & Interop Bridge Endpoints (`server.js:3000`)
| Endpoint | Method | Auth | Description |
|---|---|---|---|
| `/api/platform/all` | `GET` | Public / Local | Snapshot of plans, printer options, coupons, users, and remote config. |
| `/api/platform/events` | `GET` | SSE Stream | Real-time Server-Sent Events stream for mobile app and web portal. |
| `/api/platform/update` | `POST` | Admin | Updates platform configuration and notifies connected devices. |
| `/api/platform/order-hardware` | `POST` | Mobile / Web | Places a hardware POS printer order from the mobile checkout flow. |
| `/api/platform/sync-tenant` | `POST` | Bridge | Synchronizes tenant subscription state and plan parameters. |
| `/api/platform/sync-user` | `POST` | Bridge | Syncs user profiles and role assignments. |
| `/api/platform/user/:id` | `DELETE` | Bridge | Deletes a user from the directory. |

---

## Features & Functionalities

### 1. Multi-Tier Product Pricing (Wholesale, Retail, Customer/MRP)
- Provides FMCG distributors with 3 distinct pricing tiers per SKU:
  - **Wholesale Price**: Bulk rate for sub-distributors and high-volume dealers.
  - **Retail Price**: Standard rate for corner kirana stores.
  - **Customer / MRP Price**: Maximum retail price printed on product packaging.
- Displayed across `InventoryTab` cards and `OrderTakerFlow` with real-time gross margin calculation.

### 2. Kaccha Bill / Proforma Estimated Billing
- Informal non-taxable estimate bills ("Kaccha Bills") designed for traditional Indian FMCG distribution without mandatory GST taxation.
- Generates thermal-formatted receipts with 58mm/80mm ESC/POS Bluetooth printing, WhatsApp sharing, and balance adjustments.
- Retains 100% functionality under Freemium mode.

### 3. Sales Returns & Automatic Inventory Restock Engine
- Enables field reps to accept returns directly at retailer storefronts.
- Captures return reasons (Damaged Packaging, Expiry Date Exceeded, Order Quantity Surplus).
- Automatically increments inventory warehouse stock and applies credit reduction to customer Khata dues.

### 4. Subscription Express Checkout & Thermal Printer Bundling
- Streamlined subscription checkout in `SubscriptionCheckoutScreen`:
  - Plan selection (Startup, Grow, Enterprise) with monthly/annual billing toggles.
  - Optional wireless POS Bluetooth Thermal Printer bundling (Standard 58mm, Countertop 80mm, Rugged Van Delivery).
  - Promo code redemption engine supporting trial passes and flat rupee discounts.
  - Automatic shipping address capture and live order forwarding to Super Admin bridge.

### 5. In-Hand Cash Tracking & Dismissible Daily Reminders
- Upper left metric bar on `DistributorDashboard` prominently features real-time **In-Hand Cash** (`AppState.inHandCash`).
- Daily follow-up reminders appear on the dashboard with 1-click dismiss/snooze options stored in `SharedPreferences`.

### 6. Bill Deletion & Complete Financial Reversal Engine
- When an invoice is deleted, `AppState.deleteInvoice()` atomically:
  - Decrements customer outstanding dues by unpaid balance.
  - Restores inventory quantities for all items on the bill.
  - Writes an `INVOICE_CANCELLED` audit entry to the double-entry ledger.

### 7. Consolidated Multi-Dimensional Reports Hub
- Dedicated analytical screens in `features/reports/`:
  - `InventoryReportScreen`: SKU valuation, reorder alerts, dead-stock analysis.
  - `LedgerGraphicalReportScreen`: Visual dues trendlines, aging analysis of market dues.
  - `OrdersReportScreen`: Order status breakdowns, fulfillment velocity.
  - `SalesReportScreen`: Turnover trends, revenue by beat/route and salesperson.
  - `ReportsScreen`: 1-click CSV and WhatsApp exports.

### 8. Double-Entry Khata Ledger & Payment Collections
- Zero-drift mathematical reconciliation:
  - Debits customer account (`+amount`) upon billing.
  - Credits customer account (`-amount`) upon payment collection (Cash/UPI/Razorpay).
  - Enforces ledger balance invariants across all transactions.

### 9. Interactive In-App Notification Banners & Realtime Broadcasts
- Real-time notification listener via `SupabaseService` and `NotificationService`.
- Interactive top slide-in notification popup banners with auto-dismiss (4.5s), manual swipe-to-dismiss, and 1-tap expansion into `NotificationCenterModal`.
- Filter tabs for Unread, All, and System Announcements.

### 10. Comprehensive Camera & Gallery Image Picker Utility
- `AppImageHelper` provides centralized image selection from camera or photo gallery.
- Seamlessly resolves local device storage files (`FileImage`) vs remote HTTPS URLs (`NetworkImage`) with built-in error handling and graceful fallbacks.

---

## Design System

- **Color Palettes**:
  - Executive Royal Blue: `#1E56E2`
  - Deep Navy: `#1E3A8A`
  - Signature Brand Yellow: `#FFD233` / `#FFCC00`
  - Emerald Green (Paid / Positive): `#059669` / `#10B981`
  - Amber Warning (Dues / Caution): `#D97706` / `#F59E0B`
  - Crimson Red (Overdue / Delete / Error): `#DC2626` / `#EF4444`
- **Surfaces**:
  - Light Mode: Slate White (`#F8FAFC`), Soft Blue Tint (`#EFF6FF`), Clean White (`#FFFFFF`).
  - Dark Mode: Midnight Slate (`#0F172A`), Charcoal Slate (`#1E293B`), Surface Tint (`#334155`).
- **Typography**: Inter / System Sans, font weights w500 normal, w700 bold, w800/w900 titles.
- **Geometry & Borders**: Modern 16px to 20px rounded corners (`BorderRadius.circular(16)`), 1px slate borders (`#E2E8F0` / `#334155`).
- **Floating Action Buttons**: Standardized circular shape (`shape: BoxShape.circle` / `CircleBorder()`).
- **Tactile Feedback**: `HapticFeedback.selectionClick()` on tabs; `mediumImpact()` on primary actions.

---

## External Integrations

- **Supabase Platform**: PostgreSQL 15+ multi-tenant database, Supabase Auth, Storage, and Realtime WebSocket Channels.
- **Firebase Ecosystem**: Cloud Firestore, Firebase Authentication, Cloud Storage, Cloud Functions.
- **Razorpay**: Online payment gateway integration with HMAC-SHA256 webhook settlements.
- **BharatQR & Dynamic UPI**: Merchant VPA string generation with embedded invoice amounts and WhatsApp sharing.
- **ESC/POS Bluetooth Thermal Printers**: Wireless 58mm and 80mm thermal receipt printing protocol.
- **Courier Logistics Integration**: BlueDart, DTDC, and Delhivery tracking number assignment for POS hardware orders.

---

## Testing & Quality Assurance Verification

| Test Suite File | Coverage Scope | Status |
|---|---|:---:|
| `admin_panel_governance_test.dart` | Super admin governance and permissions | Passing |
| `app_image_helper_test.dart` | Camera/gallery image picker & URL/file resolution | Passing |
| `bank_accounts_limit_test.dart` | Maximum bank account enforcement | Passing |
| `card_and_list_view_toggle_test.dart` | Card vs. list display toggles across catalog & parties | Passing |
| `cross_module_financial_and_inventory_sync_test.dart` | Cross-module circular stock & financial sync | Passing |
| `daily_reminders_dismissible_test.dart` | Dismissible reminders persistence & date reset | Passing |
| `distributor_profile_modal_test.dart` | Profile identity & banking separation | Passing |
| `enterprise_notifications_and_popup_test.dart` | Notification service, in-app banners & broadcast center | Passing |
| `five_requirements_verification_test.dart` | 5 specific core FMCG distribution requirements | Passing |
| `frontend_features_test.dart` | GST engine, formatters, models | Passing |
| `gst_billing_toggle_test.dart` | GST invoicing toggle switch | Passing |
| `hardware_settings_modal_test.dart` | ESC/POS thermal printer setup | Passing |
| `home_page_alerts_test.dart` | In-hand cash and home alerts hub | Passing |
| `inventory_tab_test.dart` | 3-tier pricing & valuation card | Passing |
| `login_logout_rbac_flow_test.dart` | Login/logout RBAC flow & 3-tab segmented control | Passing |
| `manage_custom_gst_slabs_test.dart` | Custom GST slabs configuration | Passing |
| `models_test.dart` | Model serialization invariants | Passing |
| `nine_enterprise_features_test.dart` | 9 core enterprise feature behaviors | Passing |
| `order_delete_button_test.dart` | Standalone order deletion with inventory reversal | Passing |
| `order_delivery_and_sales_data_test.dart`| Delivery handovers and sales data | Passing |
| `orders_and_pending_payments_collections_test.dart` | Orders tab pending payment badges & collections sync | Passing |
| `orders_and_reports_test.dart` | Order taker and reports downloads | Passing |
| `payment_preferences_dynamic_qr_test.dart`| Dynamic UPI QR generation | Passing |
| `printer_service_and_settings_test.dart`| Printer service & ESC/POS protocols | Passing |
| `profile_and_settings_unified_test.dart`| Unified profile & settings screen | Passing |
| `proper_order_taking_and_bill_generation_test.dart` | Order taker POS flow to instant bill generation | Passing |
| `purchase_expense_notification_test.dart`| Purchases, expenses & notifications | Passing |
| `rbac_and_subscription_gating_test.dart`| Role permissions & subscription gating | Passing |
| `rbac_clean_removal_and_consistency_test.dart`| Clean removal of unprivileged tabs | Passing |
| `reminders_and_bank_account_redesign_test.dart`| Reminders & bank accounts redesign | Passing |
| `sales_return_inventory_restock_test.dart`| Sales returns & inventory restocking | Passing |
| `security_and_subscription_audit_test.dart`| Multi-tenant security rules audit | Passing |
| `splash_screen_test.dart` | Splash screen animation & auto-navigation | Passing |
| `staff_rbac_and_notifications_test.dart`| Staff CRUD & notification drawer | Passing |
| `subscription_express_checkout_flow_test.dart`| Express checkout & printer bundling | Passing |
| `super_admin_console_test.dart` | Super admin KPI cards & pricing | Passing |
| `super_admin_portal_route_test.dart` | Super admin route guards | Passing |
| `tenant_persistence_and_profile_details_test.dart` | Tenant persistence, local storage & profile details | Passing |
| `theme_mode_toggle_test.dart` | Light and dark mode theme switching | Passing |
| `user_eight_requirements_test.dart` | 8 specific user requirements validation | Passing |
| `web_admin_seamless_sync_test.dart` | Web Admin interop & SSE sync | Passing |
| `widget_test.dart` | Base app sanity test | Passing |
| **Total Test Count** | **42 Test Suites** | **100% Passing** |

- **Flutter Static Analysis**: **0 issues found!** (`flutter analyze lib test` ran with 0 errors, 0 warnings).
- **Backend TypeScript Compilation**: **0 errors!** (`cd functions; npm run build` compiled cleanly).

---

## Client Meeting Specification Compliance Matrix

Cross-referencing the 27 operational requirements defined in `docs/CLIENT_MEETING_SPEC.md`:

| Spec Section | Requirement Summary | Implementation in Codebase |
|---|---|---|
| **§1.1 - §1.2** | Simplicity over feature density; laymen-friendly business product | Clean cards, minimal clutter, intuitive jargon-free business labels. |
| **§3.1 - §3.2** | Clean, uncluttered UI; Executive visual presentation | Standardized card radius (16px), soft ambient shadows, dual light/dark theme. |
| **§4** | Grouped navigation instead of scattered menu items | Dynamic `MainShell` tabs (`Home`, `Parties`, `Bill`, `Orders`, `Collection`). |
| **§5.1 - §5.3** | Circular profile avatar; logo or auto short-name; profile without banking | Circular monogram avatar (`_getInitials`), logo upload via `AppImageHelper`. |
| **§6** | Separate Accounts/Banking from Profile | Dedicated `AccountsScreen` accessible from Profile & Legal tab. |
| **§7 - §8** | Consolidated Reports Hub; GST downloads under Reports | `ReportsScreen` and dedicated reporting screens (`Inventory`, `Ledger`, `Orders`, `Sales`). |
| **§9** | Core Sales/Billing workflow | `OrderTakerFlow`, `EstimatedBillScreen` (Kaccha), `GstTaxInvoiceViewer` (Pucca). |
| **§10** | Purchase Module (Stock Inward logging) | `PurchaseScreen` & `RecordPurchaseScreen` with instant stock addition. |
| **§11** | Simple Expense Module | `ExpenseScreen` with quick category buttons and instant In-Hand Cash deduction. |
| **§12** | Inventory & 3-Tier Pricing | `InventoryTab` displaying Wholesale, Retail, and Customer/MRP cards. |
| **§13 - §15** | Staff Management & Granular Module Permissions | `StaffManagementScreen` with 10 permission switches per role. |
| **§16** | Reusable business platform for multiple roles | Multi-role support (`owner`, `salesman`, `delivery`, `accountant`, `manager`). |
| **§17.1** | Clean header with company identity and centered brand | Top app bar in `MainShell` with centered "Sales Army" badge. |
| **§17.2** | Remove technical sync indicators from header | Replaced with silent background sync; notification bell preserved. |
| **§18** | Time-based greeting without username | "Good Morning", "Good Afternoon", "Good Evening" based on current hour. |
| **§19** | Non-intrusive notification center & detail view | Bell icon with unread micro beacon; expandable `NotificationCenterModal`. |
| **§20** | Reminders accessible with notifications | `RemindersScreen` and Reminders sub-tab on `VisitsTab`. |
| **§21** | Dismissible home screen notices with daily persistence | Daily dismissals for milestone banners, reminders, and alerts with undo. |
| **§22 - §24** | Card-based layout & curated high-frequency action dashboard | 2x2 quick action cards and 8-action fintech dock on `DistributorDashboard`. |
| **§26** | Dedicated Settings module (Printers & Hardware) | `PrinterSettingsScreen` & `HardwareSettingsScreen` under Settings & Hardware tab. |
| **§27** | Plan & Pricing module | Dedicated `PlanAndPricingScreen` and `SubscriptionCheckoutScreen`. |

---

## Known Issues

1. **Flutter Build Dependency Validation Flag**:
   - When running CLI builds with `flutter build apk`, passing `--android-skip-build-dependency-validation` bypasses Gradle version validation notices and compiles cleanly.

---

## Technical Debt

1. **Relational Database Production Migration**:
   - The Supabase relational schema is fully mapped (`COMPLETE_SUPABASE_SETUP.sql` and `SupabaseService.dart`). In production deployments, setting `SUPABASE_URL` and `SUPABASE_ANON_KEY` environment variables connects the mobile app and Web Admin bridge directly to live Supabase cloud instances.
2. **Delivery Handover Confirmation Workflow**:
   - The delivery handover state machine (OTP delivery verification / agent handover code) is tagged `BLOCKED — CLIENT CONFIRMATION REQUIRED` pending final client specification.

---

## Change Log

### 2026-10-20
#### Comprehensive Full Codebase Deep Audit, Supabase Dual-Backend Integration & Client Spec Modernization
- **Dual-Backend Relational Architecture (Supabase PostgreSQL + Firebase NoSQL)**:
  - Created `SupabaseService` (`apps/mobile/lib/core/services/supabase_service.dart`, 1,092 lines) providing end-to-end integration with Supabase PostgreSQL, Supabase Auth, Realtime Channels, and Storage.
  - Implemented standalone PostgreSQL setup script (`supabase/COMPLETE_SUPABASE_SETUP.sql`) and migration scripts (`20261012000000_init_salesarmy_schema.sql`, `20261012000001_supabase_rbac_and_auth.sql`) defining 17 relational tables with composite indexes, triggers, and Row Level Security (RLS) policies.
  - Connected Web Admin bridge (`server.js`) to Supabase via zero-dependency PostgREST and Auth API helpers (`postgrestRequest`, `supabaseAuthRequest`).
- **Client Meeting Specification Compliance (`docs/CLIENT_MEETING_SPEC.md`)**:
  - Validated and audited all 27 operational principles: circular company monogram avatar, separation of profile and banking, consolidated reports hub, simplified purchase/expense tracking, granular staff RBAC module permissions, time-based greetings without username, dismissible daily notices, and high-frequency action dashboard.
- **Enterprise In-App Notification System & Realtime Broadcasts**:
  - Built `NotificationService` (`apps/mobile/lib/core/services/notification_service.dart`) with interactive top slide-in popup banners, auto-dismiss timers, haptic feedback, and 1-tap transition to `NotificationCenterModal`.
- **Centralized Media & Image Utility (`AppImageHelper`)**:
  - Implemented camera and photo gallery picker with intelligent local device storage (`FileImage`) vs network URL (`NetworkImage`) resolution and graceful error handling.
- **Quality Assurance & Verification**:
  - Expanded test suite to **42 comprehensive test files** with 200+ assertions.
  - **Flutter Static Analysis**: **0 issues found** (`flutter analyze lib test` ran cleanly across all files).
  - **Backend TypeScript Compilation**: **0 errors** (`npm run build` in `functions/`).

### 2026-10-12
#### Cross-Module Circular Reactivity & Full Functional Synchronization
- **End-to-End Circular Business Engine Synchronization**:
  - Unified all accounting flows across `Sales`, `Orders`, `Invoices`, `Khata Ledgers`, `Customer Dues`, `In-Hand Cash`, `Bank Accounts`, `Purchases`, `Expenses`, and `Sales Returns`.
  - **Orders to Invoices**: `CompleteAndBillOrderModal` guarantees invoice creation for both GST and Non-GST orders, immediately decrementing catalog inventory and adjusting party balances.
  - **OrdersTab Standalone Billing**: Automated instant payment recording when bills are marked paid or partial, updating cash balances and party ledger in real time.
  - **Double-Entry Financial Reversal**: Implemented `deletePayment` and enhanced `deleteInvoice` with complete double-entry reversal (restores stock, cancels linked orders, deducts uncollected dues).
  - **Stock Inward & Outward Sync**: `addPurchase` increments live product stock, updates supplier dues or deducts cash, and automatically creates catalog items with preserved 3-tier pricing (Wholesale, Retail, Customer/MRP).
  - **Sales Returns**: Restores batch inventory, issues credit notes, and offsets customer outstanding dues with complete circularity.

### 2026-10-12
#### Executive UI Beautification, Clutter Elimination & Codebase Sanitization
- **Clutter & Mockup Removal**:
  - Eliminated hardcoded dummy stores from `DistributorDashboard`, replaced with an elegant empty state card when no store records exist.
  - Eliminated misleading fallback values, now strictly rendering authentic dynamic business metrics.
  - Removed redundant mock strips ("Shift Beat", "Delivery Van", "Warehouse Sync") from the Executive Financial Slate card.
- **Visual Elegance & Professional Polish**:
  - Streamlined `_buildMilestoneBanner` into a sleek executive card with clean turnover metrics.
  - Streamlined `ProfileAndSettingsScreen` settings row subtitles to concise, modern phrases.

#### Web Admin Remote App Governance & Live Multi-Tenant Control
- **Full App Control via Web Admin Portal (`apps/web-admin/`)**:
  - Implemented bidirectional bridge synchronization between Web Admin (`server.js` on Port 3000) and Flutter Mobile App (`_processBridgePlatformData`).
  - Added remote kill switch enforcement across 13 modules (`order_taking`, `gst_invoicing`, `collections`, `gps_tracking`, `thermal_printer`, `soundbox_audio`, `staff_management`, `van_stock`, `customer_portal`, `instant_sync`, `purchases`, `expenses`, `reports`).
  - Emergency Maintenance Mode: Super admin can toggle maintenance mode with custom broadcast message and recovery ETA.
  - Emergency Broadcast Dispatch: Admin can broadcast real-time alert/info/critical banners to all active mobile devices.
  - Multi-Tenant & Subscription Control: Super admin can change tenant subscription tiers (`Startup`, `Grow`, `Enterprise`), toggle subscription statuses (`active`, `trial`, `suspended`), and toggle freemium selling permissions.

### 2026-10-10 (Phase 3)
#### Subscription Express Checkout, Coupon Engine & Remote Governance
- **Express Subscription Checkout (`SubscriptionCheckoutScreen`)**:
  - Implemented multi-tier plan selection (Startup, Grow, Enterprise) with monthly/annual billing toggles.
  - Bundled optional wireless POS Bluetooth Thermal Printers (58mm, 80mm, Rugged) with automatic hardware order forwarding.
  - Built promo coupon redemption supporting free trial passes and flat rupee discounts.
- **Dynamic Role-Based Shell Tabs**:
  - Refactored `MainShell` bottom navigation to construct available tabs dynamically via `_buildAvailableTabs(appState)`.
- **Super Admin Modularization & Remote Governance**:
  - Modularized `SuperAdminConsole` into separate tab components (`AdminDashboardTab`, `AdminFeaturesTab`, `AdminPlansTab`, `AdminSettingsTab`, `AdminSubscribersTab`).

### 2026-10-06
#### UI Polish, Dark Theme & In-Hand Cash Integration
- **Full Dark Theme Support**: Added dark theme palette in `AppTheme` with persistent state in `AppState` and `SharedPreferences`.
- **In-Hand Cash Metric & Reminders**: Real-time In-Hand Cash on `DistributorDashboard`; dismissible daily reminder cards with daily snooze tracking.
- **Circular FAB Standardization**: Standardized Floating Action Buttons to circular BoxShape geometry.

### 2026-10-02 (Phase 2)
#### Kaccha Bills, Sales Returns, Reporting Hub & Web Admin Portal
- **Kaccha / Estimated Billing (`EstimatedBillScreen`)**: Informal non-taxable proforma billing slips with thermal 58mm/80mm Bluetooth printing and Freemium Selling guarantee.
- **Sales Returns & Restocking (`SalesReturnDialog`)**: Line-item returns with return reasons, automatic inventory restock, and Khata dues credit adjustment.
- **Consolidated Reporting Hub (`features/reports/`)**: Added `InventoryReportScreen`, `LedgerGraphicalReportScreen`, `OrdersReportScreen`, and `SalesReportScreen`.
- **Web Admin Portal (`apps/web-admin/`)**: Created standalone web-based Super Admin dashboard with Node.js interop bridge server (`server.js:3000`).

### 2026-09-19
#### Profile & Settings Consolidation & Global UI Refinement
- Combined `ProfileScreen` and `SettingsScreen` into unified `ProfileAndSettingsScreen` with 2-segment controller (`Profile & Legal` and `Settings & Hardware`).
- Modernized `MainShell` bottom navigation bar with animated pill indicators.

### 2026-09-17 / 2026-09-18
#### Client Specification Implementation & Module Decoupling
- Decoupled monolithic configurations into dedicated screens: `ProfileScreen`, `AccountsScreen`, `ReportsScreen`, `StaffManagementScreen`, `PurchaseScreen`, `ExpenseScreen`, `SettingsScreen`, and `PlanAndPricingScreen`.
- Implemented silent background sync, removing manual cloud sync buttons from user headers.
- Time-based greeting strictly formatted without user name.
- 8-action fintech dock on Dashboard.

### 2026-09-14
#### Mobile Redesign & Flow Modernization
- Restructured navigation into balanced pillars with executive headers and monogram avatar.
- Replaced dark boxes with executive clean cards and ambient shadows.

### 2026-09-13
#### Yellow Brand UI Modernization & Initial Project Memory
- Created initial `PROJECT_CONTEXT.md` as single-source-of-truth memory.
- Standardized design system on signature yellow brand accent (`#FFD233` / `#FFCC00`) and midnight slate typography (`#0F172A`).

### 2026-09-12
#### Multi-Tier Pricing & Financial Reversal
- Added Wholesale, Retail, and Customer/MRP price tiers across models, entities, and order taker.
- Implemented bill deletion engine with atomic customer dues reduction, product stock restoration, and `INVOICE_CANCELLED` ledger entries.
- Added scheduled data backup exporter and `BackupManagerModal`.

### 2026-09-11
#### Clean Architecture & Hexagonal Domain Engines
- Initial Monorepo reorganization into `apps/mobile` and `functions/`.
- Hexagonal pure domain engines (`TaxEngine`, `LedgerEngine`, `IdempotencyEngine`) in TypeScript.
- Offline Outbox synchronization manager with UUIDv4 idempotency tokens.

---

### Phase 20: SaaS Subscription & Plan Governance Audit

#### 1. Default Signup Plan
- **Plan ID**: `startup` (Startup Plan)
- **Status**: `trial`
- **Duration**: 14 Days Free Trial (`defaultTrialDays` remotely configurable via Super Admin Panel)
- **Freemium Guarantee**: Order taking, kaccha estimate bills, full GST tax invoicing, thermal printing, and offline outbox are 100% UNRESTRICTED across all tiers and after trial expiry.

#### 2. Plan Tier Hierarchy & Enforced Limits
| Plan Tier | Monthly Price | Yearly Equivalent | Catalog Products | Staff Seats | Retail Shops | Key Feature Unlocks |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Startup Tier** (`startup`) | ₹399/mo | ₹319/mo | Up to 50 Products | 1 User (Proprietor seat) | Up to 200 Shops | Core Invoicing, Estimates, 58mm POS, Local Cloud Sync |
| **Grow Plan** (`grow`) | ₹599/mo | ₹479/mo | Up to 200 Products | Up to 5 Staff Users | Up to 1,000 Shops | Dynamic UPI QR, Van Stock, Automated 12PM/10PM Batch Sync |
| **Enterprise Plan** (`enterprise`) | ₹899/mo | ₹719/mo | Unlimited (9,999+) | Up to 50 Staff Seats | Up to 10,000 Shops | Multi-Van Fleet, Custom Tax Slabs, Audit Vault, 24/7 Account Mgr |

#### 3. Administrative Control & Parity (Web Admin Portal)
- **Platform Settings (`#view-settings`)**: Direct remote control of `defaultPlanId` (startup/grow/enterprise), `defaultTrialDays` (e.g. 14 days), and `trialGracePeriodDays` (e.g. 3 days), instantly persisted to `/api/platform/settings` and synced with mobile clients via Cloud Bridge and Supabase PostgreSQL.
- **Tenant Inspector**: Super Admins can one-click assign or upgrade/downgrade any agency to `Startup`, `Grow`, or `Enterprise`, or grant `+7d`, `+14d`, `+30d` trial extensions with live cloud propagation.


