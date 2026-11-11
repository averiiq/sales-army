# Sales Army — Client Meeting Implementation Specification

> **Source:** Client development meeting transcript provided for this task.  
> **Purpose:** Convert the discussed requirements into an implementation-ready specification for the development team / Anti-Gravity coding agent.
>
> **Important:** This document preserves the requirements actually discussed in the meeting. Where the discussion was incomplete, ambiguous, or explicitly deferred, that item is marked accordingly rather than being silently invented.

---

## 1. Product Direction

### 1.1 Core objective

The client wants the application to become a **solid, production-quality business-management product**, not merely an application that is technically functional and then launched.

The product should be:

- Easy to understand.
- Clean and uncluttered.
- Simple enough for a business owner / non-accounting user.
- Flexible enough to support businesses with staff.
- Structured around modular business operations.
- Capable of supporting different user roles.
- Designed so that the same product can serve more than one business-user scenario instead of being unnecessarily restricted to a single user type.

### 1.2 Primary UX principle

The application should prioritize **simplicity and ease of use over feature density**.

The client explicitly contrasted the desired product with an existing/reference business app that contains many options and is comparatively complicated.

The desired experience is:

> A person without accounting knowledge should be able to use the application naturally for day-to-day business operations.

The app should therefore avoid:

- Unnecessary options.
- Overloaded screens.
- Accounting-heavy terminology where a simpler term can be used.
- Excessive menus.
- Duplicate access points that create confusion.
- Features being exposed directly on the home screen merely because they exist.

---

# 2. Reference / Competitive UI Study

The client is using another business application as a **reference**, not as a product to copy.

The reference is being considered for:

- UI/UX inspiration.
- Understanding how features are organized.
- Understanding what features are exposed.
- Comparing information architecture.
- Identifying areas where the current application can be improved.

### Important distinction

The client explicitly stated that the reference application is comparatively complicated and appears oriented toward users such as accountants.

The target product should instead serve a **general business user / layman** who may have little or no accounting knowledge.

Therefore:

- Do not blindly replicate the reference application's navigation.
- Do not replicate its excessive options.
- Use the reference primarily to understand patterns and improve the product.

---

# 3. Overall UI/UX Direction

## 3.1 Visual direction

The application currently feels too **busy / messy / congested**.

The desired direction is:

- Clean.
- Simple.
- Professional.
- Easy to scan.
- Visually balanced.
- Less crowded.
- Card-based where appropriate.
- Clear hierarchy.
- Minimal unnecessary text and controls.

## 3.2 Theme

The client liked the general presentation / structure of the referenced design and requested that the application move toward a similar overall presentation.

However:

- The application's color scheme should be changed.
- The exact final colors were not finalized in this meeting.
- The visual structure should remain clean rather than copying the reference literally.

### Implementation rule

Use the reference primarily for:

- Layout density.
- Card presentation.
- Information hierarchy.
- Navigation clarity.

Do **not** assume that its exact colors, branding, labels, or functionality should be copied.

---

# 4. Navigation / Menu Architecture

The existing/reference menu contains too many options.

The target application should simplify navigation.

### Required principle

Features should be grouped logically instead of exposing every operation directly.

Examples discussed:

- Profile/company information should be grouped into **Profile**.
- Banking/company financial information should be grouped appropriately under **Accounts**.
- Downloads such as GST bills/statements should be available under **Reports**, rather than being scattered throughout other screens.
- Printer configuration should be placed under **Settings**.
- Staff/user management should be grouped under **Utilities → Staff**.
- Plan & pricing should have a dedicated location.
- Reminders and notifications should be logically accessible without cluttering the primary interface.

---

# 5. Profile Module

## 5.1 Profile entry

The user should be able to click the profile/company area and open a clean profile screen.

The profile representation should be **round/circular**, not square.

## 5.2 Profile identity display

The company identity area should support:

1. Company logo.
2. Company short name / abbreviation.
3. Automatic short-name generation when appropriate.
4. Company name display.

The client discussed the possibility of:

- Showing the company logo if the user has uploaded one.
- Otherwise showing an automatically generated short form of the company name.
- Example discussed conceptually: if a company has a longer name, show its first few letters as a compact identity.

### UX requirement

Do not allow a long company name to consume excessive header space.

The header should remain compact.

## 5.3 Profile information

The Profile module should contain:

- Company name.
- Owner name.
- Owner contact number.
- Owner email address.
- Company address.
- Company GST information.

### Do NOT put banking details into the main Profile information section

The meeting explicitly separated banking/account information from the basic company profile.

Bank/account information should be handled through the **Accounts** area.

---

# 6. Accounts / Banking Information

Bank/account information should be separated from the basic company profile.

### Requirement

Create/use a dedicated **Accounts** area for:

- Company banking information.
- Relevant financial/account information.

The meeting did not fully define all fields or workflows for the Accounts module.

Therefore:

> Do not invent additional account fields or accounting workflows at this stage. Keep this module extensible and wait for the module-level discussion.

---

# 7. GST / Company Information

Company GST information is part of the company's information.

The client stated that:

- GST-related company information should be available with the company's information.
- GST bill downloads should not clutter the main interface.
- GST bill/document downloads should be placed under **Reports**.

Exact GST fields were not specified in the meeting.

Do not invent a field list beyond the discussed requirement.

---

# 8. Reports Module

Reports should become the central location for downloadable/generated business documents and relevant historical information.

## 8.1 GST bill/document downloads

Any GST bill download functionality currently exposed in other areas should be moved into **Reports**.

### Objective

Instead of placing:

- Download buttons
- GST document links
- Other downloadable links

throughout multiple modules, consolidate them under Reports.

This saves UI space and reduces confusion.

## 8.2 Statement / historical data

The meeting also referenced the concept of downloading a statement for a selected period.

The exact final report structure was not finalized.

Therefore the Reports module should be designed to support:

- Date/period selection.
- Report generation.
- Download/export where applicable.

But the exact report types and formats should be finalized during the individual Reports-module discussion.

---

# 9. Sales / Billing

The client confirmed that **bill creation is a core Sales operation**.

The application should support a Sales workflow where a business can:

- Create a bill.
- Record a sale.
- Track relevant order/sales information.

The client also stated that the product needs to account for:

- Goods sold.
- Amount received.
- Outstanding amount.
- Customer/order information.

The detailed billing fields and workflow were **not fully discussed in this meeting**.

Do not redesign the entire billing engine without the later module-specific discussion.

---

# 10. Purchase Module

A **Purchase** option needs to be added.

The conceptual requirement is:

> Sales = goods/services being sold.  
> Purchase = goods/material being purchased by the business.

The meeting explicitly identified Purchase as a missing business operation.

### UI requirement

Purchase should be presented as a clean, simple business operation rather than an accounting-heavy interface.

### Detailed Purchase workflow

Not finalized in this meeting.

Further module-level discussion is required for:

- Purchase fields.
- Supplier flow.
- Purchase status.
- Payment tracking.
- Purchase history.
- Inventory integration.
- Reports.

---

# 11. Expense Module

An **Expense** module/option needs to be added.

The intended concept is simple:

> Record what the business spent money on.

The client explicitly rejected an unnecessarily complicated presentation.

### Expense UX

The operation should be straightforward:

1. Add an expense.
2. Enter the relevant expense information.
3. Save it.
4. Make it available for relevant business records/reports.

### Detailed fields

The client said they would explain the exact fields/options later.

Therefore do not invent an extensive accounting expense schema yet.

---

# 12. Inventory / Stock

Inventory/stock is a core module.

The meeting indicated that:

- Stock/inventory functionality already exists conceptually.
- Adding a shop/product and recording related information is comparatively straightforward.
- The **Order workflow** is considered much more important and requires dedicated discussion.

### Important

Do not assume that Inventory is fully finalized simply because an Inventory screen already exists.

A later module-level discussion is required to determine:

- What should appear inside Inventory.
- What actions should be available.
- What information should be displayed.
- How inventory interacts with Purchase.
- How inventory interacts with Sales/Orders.

---

# 13. Staff / User Management

One of the major architectural changes discussed is the introduction of **staff/user roles**.

The application should not be restricted to a single owner/operator.

It should support businesses where:

- Owner uses the application alone.
- Owner has an accountant.
- Owner has delivery personnel.
- Owner has field/marketing staff.
- Other employees require controlled access.

---

# 14. Staff Module

A dedicated:

**Utilities → Staff**

section should be used.

The client specifically suggested changing a generic/reference option such as “Sync and Share” into **Staff**.

## 14.1 Add staff member

The owner/admin should be able to add a staff member.

The discussed fields are:

- Staff/user name.
- Staff email address.
- Staff role.

## 14.2 Role assignment

Each added staff member should have a defined role.

Examples explicitly discussed:

- Owner.
- Accountant.
- Delivery staff.
- Field/marketing staff.

The exact final role catalogue was not finalized.

Therefore the architecture should support configurable roles rather than hardcoding a small fixed set unnecessarily.

---

# 15. Module-Level Permission System

This is a major requirement.

The application architecture is expected to be modular.

Examples discussed include modules such as:

- Billing.
- Product addition.
- Profile access.
- Orders.
- Other business operations.

Each module should be independently permission-controlled.

## 15.1 Permission UI

When creating/editing a staff user:

1. Select/create the user.
2. Define their role.
3. Display available application modules.
4. Provide a toggle/switch for each module.
5. Enable only the modules that the staff member is allowed to access.

Conceptually:

```text
Staff Member
    ↓
Role
    ↓
Module Permissions
    ├── Billing       ON/OFF
    ├── Products      ON/OFF
    ├── Profile       ON/OFF
    ├── Orders        ON/OFF
    ├── Inventory     ON/OFF
    └── Other Modules ON/OFF
```

## 15.2 Permission principle

A delivery employee should not need access to the entire application.

Example discussed:

> A delivery person receives an order and needs to deliver it.

Therefore that user should only receive the permissions necessary for delivery-related operations.

## 15.3 Owner vs staff

If the owner is operating the application alone:

- The owner can access the required modules directly.

If the owner assigns work to staff:

- The staff member should operate through their assigned role/permissions.

This allows the same application to support:

### Single-user business

```text
Owner
  ↓
All required operations
```

### Staff-based business

```text
Owner
 ├── Accountant
 ├── Delivery Staff
 ├── Field Staff
 └── Other Staff
```

---

# 16. Business Model / Target Audience Expansion

The client wants to avoid unnecessarily restricting the product to one narrow user category.

The discussion evolved from:

- B2C
- B2B

toward a broader reusable business product.

The central idea is:

> The same underlying business-management product can be used by different business participants, with terminology and access determined by their role/use case.

The product should therefore be designed as a **general business operations platform**, rather than a tool that only works for one specific business relationship.

### Architectural implication

Do not create separate fundamentally different applications for:

- Manufacturer.
- Shop owner.
- Customer-facing sales operator.
- Delivery worker.

Instead, use:

- Common modules.
- Role-based access.
- Appropriate workflows.
- Permission controls.

---

# 17. Home Screen Redesign

The existing Home screen is considered **too congested**.

The client explicitly wants it simplified.

## 17.1 Header

The top section should contain a compact company identity.

### Company identity

Display:

- Company logo OR
- Short company name/abbreviation.

Avoid displaying the full long company name when it creates excessive space consumption.

### Center branding

The discussed design includes a small centered:

- App/company identity such as “Sales Army”
- Small logo

The exact final visual arrangement can be refined during implementation.

## 17.2 Remove unnecessary cloud/sync indicator

The cloud/sync icon currently shown in the header should **not be visibly exposed** in the primary home screen.

The underlying synchronization functionality should continue to work if required, but the user should not have to see a technical sync indicator unnecessarily.

### Principle

Technical implementation details should not clutter the business user's interface.

---

# 18. Greeting

The home screen should display a simple time-based greeting.

Examples:

- Good Morning
- Good Afternoon
- Good Evening

The greeting should be automatically selected based on the current time.

The user's name should **not** be displayed in this greeting area.

The meeting also indicated that the time itself does not need to be separately displayed as a prominent UI element.

---

# 19. Notification System

Notifications should remain accessible but should not consume unnecessary home-screen space.

## 19.1 Notification placement

The notification area should be positioned in the upper/home navigation area in a clean way.

The discussion considered placing it around the area between the navigation/header sections.

The exact final pixel-level placement is a UI implementation decision, but it must remain visually uncluttered.

## 19.2 Notification detail view

Clicking a notification should open a proper notification-detail view.

The detail view must support:

- Full notification text.
- Long notifications.
- Easy reading.
- Clear hierarchy.

A notification should not be truncated in a way that prevents the user from understanding it.

---

# 20. Reminders

Reminders are an explicit feature requirement.

The application should provide access to:

- Reminders.
- Notifications.

The client discussed placing the reminder/notification functionality together in the application's information architecture.

### Detailed reminder workflow

Not finalized in this meeting.

The later module discussion must define:

- Creating reminders.
- Reminder date/time.
- Repeat rules, if any.
- Completion/dismissal.
- Notification behavior.
- Reminder list.

Do not invent these behaviors before confirmation.

---

# 21. Dismissible UI Elements

Some home-screen informational/notification elements should support dismissal/removal.

The client explicitly discussed having a mechanism to remove/hide an item rather than keeping it permanently visible.

### Requirement

Where the relevant home-screen card/banner is dismissible:

- Provide a clear remove/dismiss action.
- Remove it from the visible home screen after dismissal.
- Do not confuse dismissal with permanent deletion of underlying business data.

---

# 22. Home Screen Cards

The main business information should use a **card-based layout**.

The existing large/congested presentation should be replaced with cleaner cards.

### Card principles

Cards should:

- Have clear hierarchy.
- Use enough spacing.
- Avoid excessive information.
- Be easy to scan.
- Avoid taking unnecessary vertical space.
- Present the most important business actions/information first.

The reference application's cleaner card presentation was explicitly liked during the meeting.

---

# 23. Home Screen Feature Shortcuts

The home screen should expose a curated set of important features.

Examples discussed include:

- Bill creation.
- Add party/customer.
- Collection/payment-related action.
- Field-related operation.
- Order-related operation.
- Other high-frequency operations.

## 23.1 Do not create an unlimited customizable shortcut system

A discussion occurred about allowing users to add arbitrary shortcuts.

The conclusion was:

> Do not build an unnecessarily complicated “custom shortcut builder” at this stage.

Instead:

- Define a fixed curated set of useful home-screen shortcuts.
- Increase the number of default shortcuts where appropriate.
- Keep the set controlled by product design.

The exact final number of shortcuts was discussed as approximately eight, but the precise final set was **not finalized**.

### Therefore

Do not hardcode “exactly 8” as an immutable requirement unless confirmed later.

---

# 24. Shortcut Selection Principle

The most frequently used actions should be given priority.

The client and developer discussed that some operations are already available in their respective modules.

Example:

- Add stock already exists in the relevant module.
- Bill creation may still deserve a home shortcut because it is frequently accessed.
- Other primary actions should be surfaced based on actual frequency.

### Product rule

The Home screen is not a duplicate copy of every module.

It should be a **high-frequency action dashboard**.

---

# 25. Module Architecture

The application should continue to be developed around modular functionality.

The client explicitly described the application as having modules for things such as:

- Billing.
- Product addition.
- Profile.
- Orders.
- Inventory.
- Staff.
- Reports.
- Accounts.
- Settings.

### Architectural requirement

Each module should be independently maintainable and permission-aware.

Avoid tightly coupling unrelated modules.

---

# 26. Settings Module

Settings should contain technical/device/application configuration that does not belong in the main business dashboard.

## 26.1 Printer configuration

Printer configuration should be placed under **Settings**.

The client explicitly rejected putting printer configuration into the general Utility/home feature area.

Potential printer configuration includes:

- Printer connection/setup.
- Relevant printing preferences.

The exact supported printer types and configuration flow were not defined in the meeting.

Do not invent printer protocols or integrations yet.

---

# 27. Plan & Pricing

The application should have a **Plan & Pricing** area.

The exact location was discussed as part of the application's utility/settings/navigation architecture.

### Requirement

Provide a clear location for:

- Current plan.
- Available plans.
- Pricing information.

The meeting did not define:

- Subscription tiers.
- Prices.
- Feature limits.
- Payment flow.

These must be discussed separately.

---

# 28. Backup / Data Recovery Decision

A significant part of the meeting was spent evaluating a manual backup/restore feature.

## 28.1 Initial idea

The reference application had functionality related to:

- Adding multiple companies.
- Backup.
- Restore.

The client initially considered having a backup/restore feature.

## 28.2 Final direction from the discussion

The application is expected to maintain the user's business data through the user's account and server-side storage.

Therefore:

- A separate manual backup feature is **not considered necessary as a primary application feature** at this stage.
- The system should automatically maintain/update the user's data.
- When the user logs in from another device, the user's latest available data should be retrieved from the server/account.

## 28.3 Automatic backup/synchronization

The conceptual desired behavior is:

```text
User enters/updates business data
        ↓
Data is synchronized to server/account
        ↓
Latest state remains available
        ↓
User logs into another device
        ↓
Data is restored/synchronized from server
```

The client and developer discussed daily backup vs every-entry backup.

The conclusion was:

> A daily backup concept is preferable to performing a separate backup for every individual entry, because businesses may create anywhere from very few to thousands of entries per day.

However, later discussion moved toward the understanding that the application already maintains account/server synchronization and therefore an extra visible backup feature may not be useful.

### Final product interpretation

Do **not** expose a redundant manual backup UI in the primary product unless later confirmed.

The underlying data safety architecture must still be reliable.

---

# 29. Server-Side Data Persistence

The meeting assumes that the user's business data is associated with their account and maintained on the server.

The system should therefore support:

- Account-based data persistence.
- Automatic synchronization.
- Login from another device.
- Retrieval of the user's latest data.

### Critical requirement

The implementation must ensure that a user does not lose their business information simply because:

- Their phone is lost.
- Their phone is damaged.
- The application is removed/reinstalled.
- They log in from another device.

The meeting used scenarios such as:

- Phone theft.
- Accident/damage.
- Login from another device.

The business data should remain recoverable through the user's account/server-side data.

---

# 30. What NOT to Implement from the Reference App

The meeting explicitly identified several reference-app features that should not simply be copied.

Do not automatically implement:

- Multiple-company management if the target product is intended to operate around one company profile.
- Visible manual backup/restore controls if server/account synchronization already provides the required protection.
- Excessive menu options.
- Technical cloud/sync controls on the main dashboard.
- Overly complicated accounting-oriented UX.
- Arbitrary shortcut configuration that makes the UI more complex.

---

# 31. Single Company Concept

The discussion indicated that the target product is expected to work around a company's profile.

The client's direction was:

> The company profile exists as the main business identity, rather than making the product unnecessarily complicated with multiple-company management.

Therefore:

- A company profile should be associated with the account/business.
- Company information should be centralized.
- Staff should operate under the business/company.
- Modules should operate against the relevant business data.

If multi-company support is required later, it should be treated as a separate product decision.

---

# 32. Business Workflow Philosophy

The application should reflect actual business operations.

The client described a practical business scenario:

1. A business receives or creates an order.
2. The business records the order.
3. The owner may personally handle it.
4. Alternatively, the owner can assign it to a staff member.
5. A delivery person may deliver the order.
6. Delivery-related information should be recorded.
7. Payments/collections should be trackable.
8. The owner should be able to see business information without manually maintaining separate systems.

This demonstrates that the app should model **business operations**, not merely display accounting forms.

---

# 33. Staff-Based Order Example

The client specifically discussed a business where:

- Previously, one person handled orders and deliveries.
- Later, a dedicated person was hired for delivery.
- The business should not need a second application simply because staff were added.

Therefore:

```text
Without Staff
Owner
  ↓
Receive Order
  ↓
Process
  ↓
Deliver

With Staff
Owner
  ↓
Receive/Create Order
  ↓
Assign to Delivery Staff
  ↓
Delivery Staff
  ↓
Deliver Order
  ↓
Delivery/Status Data
  ↓
Owner Visibility
```

This is one of the reasons role-based access is a core architectural requirement.

---

# 34. Order Module — Highest Priority for Detailed Discussion

The client explicitly identified **Orders as the main workflow that still needs detailed discussion**.

The meeting ended while beginning the Order workflow discussion.

Therefore the current transcript does **not** contain the complete Order specification.

### What is established

The system needs to support:

- Orders.
- Order creation.
- Assignment to staff where applicable.
- Delivery workflow.
- Delivery-related status/data.
- Owner visibility.
- Different behavior depending on whether the business is owner-operated or staff-operated.

### What is NOT yet established

The transcript ends before the full Order workflow is explained.

Therefore do not invent:

- Exact order statuses.
- Exact order fields.
- Assignment rules.
- Delivery confirmation mechanism.
- Payment workflow.
- Partial payment behavior.
- Cancellation rules.
- Return workflow.
- Notifications.
- Customer communication.
- Order editing rules.

These must be captured in the next dedicated Order-module discussion.

---

# 35. Home Screen — Proposed Information Architecture Based Strictly on Meeting

A logical structure based on the meeting is:

```text
HOME
│
├── Compact Company Identity
│   ├── Logo
│   └── Short Name
│
├── Time-Based Greeting
│
├── Notifications
│   └── Open Notification Detail
│
├── Reminder / Notification Access
│
├── Business Summary Cards
│
├── High-Frequency Actions
│   ├── Create Bill
│   ├── Add Party/Customer
│   ├── Collection
│   ├── Order
│   ├── Field-related Action
│   └── Other curated actions
│
└── View All / Module Access
```

This is an information-architecture representation of the discussion, not a final visual design.

---

# 36. Suggested Main Navigation Structure

Based on the meeting, the application can be organized approximately as:

```text
MAIN NAVIGATION
│
├── Home
│
├── Sales
│   └── Billing
│
├── Purchase
│
├── Orders
│
├── Inventory / Stock
│
├── Reports
│   ├── GST Bill Downloads
│   ├── Statements
│   └── Other Reports
│
└── More / Menu
    │
    ├── Profile
    ├── Accounts
    ├── Utilities
    │   └── Staff
    ├── Plan & Pricing
    └── Settings
        └── Printer
```

**Note:** This is a structural interpretation of the meeting. The exact bottom-navigation/menu arrangement was not finalized.

---

# 37. UX Rules for the Entire Application

Every new or redesigned module should follow these rules.

## Rule 1 — Simplicity first

If an operation can be performed with fewer steps without losing necessary functionality, prefer the simpler flow.

## Rule 2 — Avoid accounting complexity

The target user may not understand accounting terminology.

Use:

- Plain language.
- Clear labels.
- Simple actions.

## Rule 3 — Do not expose every feature everywhere

A feature should have a logical home.

## Rule 4 — Avoid duplicate navigation

For example:

- GST downloads → Reports.
- Printer → Settings.
- Staff → Utilities.
- Banking → Accounts.

## Rule 5 — Home is for high-frequency actions

The Home screen should not become another full menu.

## Rule 6 — Hide technical implementation details

Users should not see technical synchronization/cloud controls unless they have a meaningful business purpose.

## Rule 7 — Use modular architecture

Business functions should remain independently manageable.

## Rule 8 — Permission-aware modules

Every module that contains sensitive/business functionality should be capable of being restricted by staff permissions.

## Rule 9 — Preserve existing functionality

UI/UX redesign should not accidentally remove existing working business logic.

## Rule 10 — Do not invent unfinished requirements

Where a module was explicitly deferred for later discussion, keep the architecture extensible and wait for the actual requirements.

---

# 38. Anti-Gravity Implementation Instructions

This section is intended to be used directly as guidance for the coding agent.

## Phase 1 — Existing Codebase Audit

Before modifying code:

1. Inspect the complete repository.
2. Identify the application framework and architecture.
3. Identify existing:
   - Screens.
   - Routes.
   - Components.
   - Services.
   - API layers.
   - Data models.
   - Authentication.
   - State management.
   - Storage.
   - Existing modules.
4. Determine which requirements from this document already exist.
5. Identify which requirements are partially implemented.
6. Identify which requirements are missing.
7. Do not immediately rewrite existing modules.

### Output expected from the audit

Create/update an implementation audit containing:

```text
Requirement
→ Existing implementation
→ Current location
→ Missing pieces
→ Required changes
→ Risk/dependencies
```

---

# 39. Phase 2 — Information Architecture Refactor

Before detailed UI implementation:

1. Review current navigation.
2. Remove unnecessary menu exposure.
3. Group related features.
4. Establish logical module ownership.
5. Ensure Reports owns report/download operations.
6. Ensure Settings owns printer/device settings.
7. Ensure Utilities owns Staff.
8. Ensure Accounts owns banking/account information.
9. Ensure Profile owns company/owner identity information.

Do not delete underlying functionality merely because its navigation location changes.

---

# 40. Phase 3 — Home Screen Redesign

Implement the Home redesign with:

- Compact company identity.
- Logo/short-name behavior.
- Time-based greeting.
- No user name in greeting.
- No visible cloud/sync icon.
- Clean notification access.
- Notification detail screen.
- Dismissible relevant home items.
- Card-based business summary.
- Curated high-frequency actions.
- Clean spacing.
- Reduced visual density.

### Do not

- Add unlimited shortcuts.
- Add technical controls.
- Fill the screen with every available module.
- Introduce arbitrary new features not present in the specification.

---

# 41. Phase 4 — Profile / Company Information

Implement:

- Company logo.
- Automatic/short identity representation.
- Company name.
- Owner name.
- Owner contact.
- Owner email.
- Company address.
- GST information.

Keep banking/account information outside the basic Profile section.

---

# 42. Phase 5 — Staff & RBAC

Implement the staff-management foundation.

### Staff creation

Support:

```text
Name
Email
Role
Module Permissions
```

### Permission model

Permissions should be modular.

Example:

```text
permissions:
  profile: true/false
  billing: true/false
  purchase: true/false
  orders: true/false
  inventory: true/false
  reports: true/false
  accounts: true/false
  staff: true/false
  settings: true/false
```

> The exact technical schema must follow the existing project's architecture and backend conventions.

### Security requirement

Permission checks must not exist only in the UI.

A hidden/disabled button is not sufficient security.

The backend/API layer must also enforce authorization where applicable.

---

# 43. Phase 6 — Reports

Move relevant document/report download actions into Reports.

At minimum, preserve the requirement for:

- GST bill/document downloads.
- Period-based statement/report capability where already supported.

Do not remove existing download functionality during the navigation redesign.

---

# 44. Phase 7 — Accounts

Create/organize a dedicated Accounts area for:

- Company bank details.
- Other account-related information already supported by the application.

Do not introduce a full accounting system without additional requirements.

---

# 45. Phase 8 — Purchase

Add/organize the Purchase module.

The module should be designed so that its data can later integrate naturally with:

- Inventory.
- Reports.
- Accounts/financial records.

But exact business rules must come from the subsequent Purchase discussion.

---

# 46. Phase 9 — Expenses

Add/organize the Expense module.

The initial UX should be simple.

Do not make it resemble a complex accountant-only workflow.

Exact fields and reporting behavior remain to be defined.

---

# 47. Phase 10 — Settings

Move technical/device configuration into Settings.

At minimum:

- Printer configuration.

Keep the architecture open for other application settings.

---

# 48. Phase 11 — Plan & Pricing

Provide the Plan & Pricing entry point.

Do not invent:

- Plans.
- Prices.
- Payment providers.
- Feature limits.

until the client provides them.

---

# 49. Phase 12 — Automatic Data Synchronization

The system should treat account/server persistence as the primary data-safety mechanism.

Ensure:

- User data is associated with the correct account/business.
- Data changes synchronize reliably.
- Login from another device retrieves the latest data.
- Data is not unnecessarily stored only on one device.
- The user can recover their business state after device loss/replacement.

### Manual backup UI

Do not expose redundant manual backup/restore controls in the main product unless later requested.

---

# 50. Order Module — Blocked Until Full Workflow Discussion

Do not consider the Orders module fully specified yet.

The next client discussion must define the complete flow.

Create a dedicated requirements section later covering:

```text
Order creation
→ Customer
→ Products
→ Quantity
→ Pricing
→ Payment
→ Status
→ Assignment
→ Delivery
→ Confirmation
→ Completion
→ Cancellation/return
→ Notifications
→ Reports
```

Only implement the parts already supported by the existing product unless the client provides the remaining business rules.

---

# 51. Non-Functional Requirements

## 51.1 Performance

The redesigned Home screen should not become slower because of additional cards/widgets.

Prefer:

- Efficient API requests.
- Appropriate caching.
- Lazy loading where appropriate.
- Pagination for large datasets.
- Avoiding unnecessary repeated API calls.

## 51.2 Responsiveness

The interface should remain usable across supported mobile screen sizes.

## 51.3 Accessibility / usability

Controls should have:

- Clear labels.
- Adequate touch targets.
- Consistent interaction patterns.
- Clear success/error states.

## 51.4 Error handling

Every network/data-dependent module should have:

- Loading state.
- Empty state.
- Error state.
- Retry action where appropriate.

## 51.5 Data integrity

Business data must not be lost when:

- Navigation changes.
- UI is redesigned.
- Staff permissions change.
- User changes device.

---

# 52. Security Requirements

Because the product will support staff accounts and business data:

### Authentication

Users must be authenticated before accessing protected business data.

### Authorization

Every staff action should be checked against the user's permissions.

### Tenant/business isolation

A staff member must only be able to access data belonging to the business/company they are assigned to.

### Server-side enforcement

Do not rely solely on:

```text
if permission:
    show button
```

The API/backend must enforce the permission as well.

### Sensitive information

Company banking/GST/account information should only be accessible to authorized users.

---

# 53. Data Model Considerations

The existing application's data model should be reviewed before implementation.

The architecture should be capable of representing:

```text
Business / Company
│
├── Owner / Account
│
├── Staff Users
│   └── Roles / Permissions
│
├── Customers / Parties
│
├── Products
│
├── Inventory
│
├── Sales / Bills
│
├── Purchases
│
├── Expenses
│
├── Orders
│
├── Deliveries
│
├── Accounts
│
├── Reports
│
├── Notifications
│
└── Reminders
```

This is an architectural representation of the discussed product direction, not a finalized database schema.

---

# 54. Acceptance Criteria — UI/UX

The redesign can be considered successful only if:

- [ ] Home screen no longer feels congested.
- [ ] Company identity is compact.
- [ ] Long company names do not dominate the header.
- [ ] Logo/short-name behavior works.
- [ ] Cloud/sync icon is not exposed unnecessarily.
- [ ] Greeting is time-based.
- [ ] User name is not unnecessarily displayed in the greeting.
- [ ] Notifications are accessible.
- [ ] Long notifications can be read completely.
- [ ] Relevant home items can be dismissed.
- [ ] Main information uses clean cards.
- [ ] Home shortcuts are curated rather than unlimited.
- [ ] Navigation is grouped logically.
- [ ] Reports contains relevant downloads.
- [ ] Printer settings are under Settings.
- [ ] Staff is under Utilities.
- [ ] Banking information is separated from Profile.
- [ ] Profile contains company/owner identity information.
- [ ] UI does not feel like an accountant-only application.
- [ ] The overall visual language is clean and professional.

---

# 55. Acceptance Criteria — Staff / Permissions

- [ ] Staff can be added.
- [ ] Staff name can be stored.
- [ ] Staff email can be stored.
- [ ] Staff role can be defined.
- [ ] Module-level permissions can be configured.
- [ ] Permissions are represented clearly in the UI.
- [ ] Restricted modules are not exposed unnecessarily.
- [ ] Backend/API authorization is enforced.
- [ ] Delivery staff can be restricted to delivery-related functionality.
- [ ] Owner can operate without staff.
- [ ] Adding staff does not require a separate application.

---

# 56. Acceptance Criteria — Data Safety

- [ ] Business data is associated with the correct account.
- [ ] Data is persisted server-side.
- [ ] Changes synchronize reliably.
- [ ] User can log in from another device.
- [ ] Latest available business data is retrieved.
- [ ] Device loss does not inherently mean business-data loss.
- [ ] Redundant manual backup UI is not exposed unless later requested.

---

# 57. Explicitly Deferred / Pending Requirements

These items were discussed but **not fully specified** in the provided transcript.

They must not be guessed.

## Pending 1 — Complete Order workflow

Highest priority pending discussion.

## Pending 2 — Inventory detailed workflow

Need exact:

- Fields.
- Actions.
- Relationships.
- Stock movement rules.

## Pending 3 — Purchase workflow

Need exact fields and business rules.

## Pending 4 — Expense workflow

Need exact fields and reporting.

## Pending 5 — Billing details

Need exact detailed billing behavior if the existing implementation is being changed.

## Pending 6 — Accounts details

Need exact banking/account fields and workflows.

## Pending 7 — Reports catalogue

Need exact report types and export formats.

## Pending 8 — Notifications

Need exact trigger/event rules.

## Pending 9 — Reminders

Need exact creation, scheduling, recurrence and completion rules.

## Pending 10 — Plan & Pricing

Need exact plans, prices, limits and payment flow.

## Pending 11 — Printer

Need exact printer support and configuration mechanism.

## Pending 12 — Final color palette

The client requested a cleaner color direction but did not finalize exact colors in the transcript.

## Pending 13 — Exact home shortcut set

The discussion suggested expanding the fixed shortcut area, but the exact final list was not locked.

---

# 58. Requirements That Must NOT Be Silently Assumed

Anti-Gravity/development agent must not treat the following as finalized unless later confirmed:

- Exact Order statuses.
- Exact Purchase fields.
- Exact Expense fields.
- Exact Inventory fields.
- Exact accounting calculations.
- Exact report list.
- Exact GST schema.
- Exact subscription plans.
- Exact pricing.
- Exact printer hardware/protocol.
- Exact notification triggers.
- Exact reminder recurrence rules.
- Exact number of Home shortcuts.
- Exact color values.
- Multi-company support.
- Any new external service/API.

If implementation depends on one of these, mark it as:

```text
BLOCKED — CLIENT CONFIRMATION REQUIRED
```

rather than inventing a business rule.

---

# 59. Implementation Safety Rules for Anti-Gravity

Before every major change:

1. Inspect existing implementation.
2. Understand dependencies.
3. Reuse existing components/services where appropriate.
4. Avoid duplicate implementations.
5. Do not replace working backend logic merely to change UI.
6. Do not break existing routes without migration.
7. Do not remove existing data fields without migration analysis.
8. Preserve existing authentication.
9. Preserve existing business data.
10. Test affected flows after every module change.

---

# 60. Suggested Development Order

The safest implementation order based on the meeting is:

```text
1. Existing Codebase Audit
        ↓
2. Navigation / Information Architecture
        ↓
3. Shared UI / Design System cleanup
        ↓
4. Home Screen redesign
        ↓
5. Profile / Company Information
        ↓
6. Staff + RBAC foundation
        ↓
7. Reports organization
        ↓
8. Accounts organization
        ↓
9. Purchase
        ↓
10. Expense
        ↓
11. Inventory refinement
        ↓
12. Order workflow
        ↓
13. Notifications + Reminders
        ↓
14. Settings / Printer
        ↓
15. Plan & Pricing
        ↓
16. Full QA / Permission testing
        ↓
17. Production readiness review
```

**Important:** Order should be moved earlier/later based on its final workflow once the client provides the missing details.

---

# 61. Final Master Checklist

## Product Direction

- [ ] Product is positioned as a simple business-management application.
- [ ] UX is suitable for a non-accounting user.
- [ ] Product is not unnecessarily restricted to one business-user type.
- [ ] Staff-based businesses are supported.

## UI/UX

- [ ] Clean visual language.
- [ ] Reduced congestion.
- [ ] Card-based dashboard.
- [ ] Compact company identity.
- [ ] Circular profile representation.
- [ ] Time-based greeting.
- [ ] No unnecessary user-name greeting.
- [ ] No visible technical sync/cloud indicator.
- [ ] Notification detail view.
- [ ] Dismissible relevant home elements.
- [ ] Curated shortcuts.
- [ ] Reference app used for inspiration only.

## Profile

- [ ] Company name.
- [ ] Company logo.
- [ ] Company short identity.
- [ ] Owner name.
- [ ] Owner contact.
- [ ] Owner email.
- [ ] Company address.
- [ ] GST information.
- [ ] Banking information kept separate.

## Accounts

- [ ] Dedicated Accounts area.
- [ ] Company banking information.
- [ ] Existing account-related functionality preserved.

## Sales

- [ ] Billing accessible.
- [ ] Bill creation preserved.
- [ ] Sales workflow preserved.

## Purchase

- [ ] Purchase module exists.
- [ ] Detailed workflow confirmed separately.

## Expenses

- [ ] Expense module exists.
- [ ] Simple add-expense UX.
- [ ] Detailed fields confirmed separately.

## Inventory

- [ ] Inventory/Stock module retained.
- [ ] Detailed inventory workflow confirmed separately.

## Orders

- [ ] Orders module retained.
- [ ] Staff assignment architecture supports orders.
- [ ] Delivery use case supported.
- [ ] Complete workflow still requires client confirmation.

## Staff

- [ ] Utilities → Staff.
- [ ] Add staff.
- [ ] Name.
- [ ] Email.
- [ ] Role.
- [ ] Module permissions.
- [ ] Backend authorization.

## Reports

- [ ] GST downloads moved to Reports.
- [ ] Statement/report functionality organized here.
- [ ] Exact report catalogue confirmed separately.

## Settings

- [ ] Printer configuration moved to Settings.
- [ ] Other technical settings remain logically grouped.

## Notifications / Reminders

- [ ] Notifications accessible.
- [ ] Long notifications readable.
- [ ] Reminder access available.
- [ ] Detailed behavior confirmed separately.

## Data Safety

- [ ] Account-based persistence.
- [ ] Server-side data.
- [ ] Automatic synchronization.
- [ ] Cross-device login/data retrieval.
- [ ] No redundant manual backup UI.
- [ ] Device loss does not inherently cause business-data loss.

## QA

- [ ] Owner flow tested.
- [ ] Staff flow tested.
- [ ] Restricted-permission flow tested.
- [ ] Unauthorized API access tested.
- [ ] Empty states tested.
- [ ] Loading states tested.
- [ ] Error states tested.
- [ ] Network failure tested.
- [ ] Cross-device data retrieval tested.
- [ ] Existing business flows regression-tested.

---

# 62. Important Source Limitation

The supplied meeting transcript ends while the client and developer are beginning to discuss the **Order workflow**.

The final recorded lines are effectively:

> The client says the main issue to discuss is how the Order workflow will work, and the transcript then cuts off.

Therefore this document deliberately does **not** fabricate the missing Order requirements.

The Order module should be treated as a **high-priority follow-up requirement** and completed from the next part of the meeting/recording if available.

---

# 63. Definition of Done

This implementation should not be considered complete merely because the screens visually resemble the discussed design.

The application is done only when:

1. The UI is cleaner and less congested.
2. Navigation reflects the intended information architecture.
3. Profile/company information is correctly separated.
4. Reports owns relevant downloads.
5. Accounts owns banking information.
6. Staff/RBAC is functional.
7. Permissions are enforced at both UI and backend levels.
8. Home shortcuts are curated.
9. Notifications/reminders have an appropriate UX.
10. Business data remains safely associated with the user's account.
11. Cross-device data recovery works.
12. Purchase and Expense foundations are implemented.
13. Inventory and Sales remain functional.
14. The complete Order workflow is implemented **only after the missing workflow requirements are confirmed**.
15. Existing application functionality has been regression-tested.
16. No unnecessary reference-app complexity has been introduced.

---

## Agent Instruction

**Do not start by rewriting the application.**

First audit the existing codebase and map every requirement in this document against what already exists.

Then implement the changes incrementally.

For every requirement:

```text
REQUIREMENT
→ AUDIT
→ PLAN
→ IMPLEMENT
→ TEST
→ VERIFY
→ MARK COMPLETE
```

If a requirement is incomplete in the source meeting, do not guess.

Mark it:

```text
BLOCKED — CLIENT CONFIRMATION REQUIRED
```

and continue with independently implementable work.

The primary objective is a **clean, simple, scalable, production-ready business application**, not a visually attractive but unnecessarily complicated clone of the reference application.
