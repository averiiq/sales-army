# SalesArmy Web-Based Admin Panel (`apps/web-admin`)

A dedicated, standalone Web Admin Portal for SalesArmy SaaS management, completely decoupled from the mobile app codebase in the monorepo structure.

## 📁 Monorepo Layout
```
sales_army/
├── apps/
│   ├── mobile/         <-- Flutter Android/iOS App Source Code
│   └── web-admin/      <-- Web-Based Super Admin Portal (HTML5, CSS3, JS ES6)
├── packages/           <-- Shared Domain & Core Packages
└── melos.yaml          <-- Monorepo Workspace Orchestrator
```

## 🚀 Key Features

### 1. Promo & Membership Trial Coupons
- **Trial Passes**: Support trial coupons (e.g. `TRIAL30`, `TRIAL14`) that grant free days of premium membership.
- **Flat Discounts**: Support fixed rupee deductions (e.g. `FLAT100`, `SAVE200`).
- **Percentage Discounts**: Support percentage-off coupons (e.g. `WELCOME50`, `FESTIVE25`).
- **Create & Publish**: Interactive modal with auto-generated code, limits, and expiration controls.
- **Live Status Toggle**: Activate or pause promo codes with 1 click.

### 2. Pricing Plans & Optional POS Printer Bundling
- Configured tiers: Free Starter (Freemium), Silver (₹499/mo), Gold (₹1,299/qtr), Platinum (₹3,999/yr).
- **POS Bluetooth Thermal Printer Add-on**: Optional hardware add-on (+₹2,499) with customer shipping address tracking.

### 3. Hardware Fulfillment Management
- Track customer orders for thermal printers.
- Manage status transitions: `Pending` -> `Dispatched` -> `Delivered`.
- Assign and update Courier Tracking (AWB) numbers.

### 4. Tenant & Unique User ID Directory
- Displays unique user IDs (`SA-USR-8821`, `SA-USR-1044`, etc.).
- Real-time subscription state: `Active`, `Trial`, `Freemium (Free)`, `Expired`.
- **Freemium Core Selling**: Confirms that non-subscribed users have 100% unrestricted access to order taking, estimated bills (kaccha bills), and tax invoices.

## 🛠️ How to Run Locally

You can launch the web admin panel using any static web server or Node/npm:

```bash
# Option 1: Using npx serve (recommended)
cd apps/web-admin
npx serve -l 3000 .

# Option 2: Using python
python -m http.server 3000

# Open in browser:
http://localhost:3000
```
