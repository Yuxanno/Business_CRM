# BUSINESS MANAGER — BUILD A COMPLETE BUSINESS MANAGEMENT APPLICATION FROM SCRATCH

## YOUR ROLE

Act as a complete senior product development team:

- Senior Product Manager.
- Senior Business Analyst.
- Senior Mobile UX/UI Designer.
- Senior Flutter Developer.
- Senior Software Architect.
- QA Engineer.

Your mission is to design and build a complete, modern, production-quality mobile application called Business Manager.

This is a single-user application designed for people who are starting or running a small independent business.

This is NOT an enterprise ERP, complex accounting platform, inventory management system, or multi-user CRM.

The goal is to give one business owner a simple and reliable way to understand their business, manage orders, track customers, record income and expenses, monitor debts, and see how much money they earn every month.

Do not simply redesign an existing interface.

Think about the product from scratch, design the user experience, establish the correct business logic, create a maintainable architecture, and implement all functionality.

The final product must feel like a polished commercial mobile application.

---

# 1. PRODUCT CONCEPT

Business Manager is a personal business management assistant.

It replaces scattered spreadsheets, notebooks, and manual calculations with one organized application.

The application must help users answer these questions:

1. How much money did I actually receive this month?
2. How much did I spend?
3. What is my actual profit?
4. How much do my customers still owe me?
5. How much do I owe other people?
6. How many orders do I currently have?
7. Which orders are completed or still in progress?
8. Which customers have outstanding payments?
9. How is my business performing compared with previous months?

The application must be easy enough for someone with no accounting experience.

## Target user

- One business owner.
- One personal business account.
- No employee management.
- No multi-company management.
- No complex permissions.
- No advanced accounting knowledge required.

The application should support different types of small businesses without forcing users into a specific industry.

---

# 2. CORE PRODUCT PRINCIPLES

Prioritize:

1. Simplicity.
2. Correct financial calculations.
3. Fast data entry.
4. Clear information hierarchy.
5. Meaningful connections between features.
6. Excellent mobile usability.
7. Consistent visual design.
8. Reliable data persistence.

Avoid:

- Unnecessary features.
- Complicated accounting terminology.
- Overloaded dashboards.
- Too many navigation destinations.
- Excessive cards.
- Repeated information.
- Unnecessary configuration.
- Decorative functionality.
- Fake statistics.
- Empty buttons.
- Features that exist without a clear purpose.

Every feature must solve a real business problem.

---

# 3. VISUAL DESIGN AND DESIGN SYSTEM

Create a premium, modern, minimalist mobile interface.

The application should look like a professional financial product rather than a generic Flutter application.

Visual inspiration:

- Premium fintech applications.
- Modern business dashboards.
- Apple Human Interface Guidelines.
- Material Design 3.
- Minimalist SaaS products.

Do not copy existing products.

Create an original, consistent design language.

## Visual style

- Clean backgrounds.
- White surfaces in light mode.
- Carefully designed dark surfaces.
- Subtle borders.
- Restrained shadows.
- Consistent rounded corners.
- Professional typography.
- Clear financial indicators.
- Minimal icons.
- Comfortable spacing.
- Balanced layouts.

Avoid huge cards, excessive gradients, oversized empty spaces, unnecessary decoration, and visual clutter.

## Color palette

Light theme:

| Token | Value |
|---|---|
| Background | #F7F8FA |
| Surface | #FFFFFF |
| Surface Variant | #F0F2F5 |
| Primary | #6366F1 |
| Primary Container | #E4E5FF |
| Text Primary | #1A1B23 |
| Text Secondary | #6B7280 |
| Text Muted | #9CA3AF |
| Border | #E5E7EB |
| Income | #10B981 |
| Expense | #F43F5E |
| Warning | #F59E0B |
| Danger | #EF4444 |

Dark theme:

| Token | Value |
|---|---|
| Background | #0F0F14 |
| Surface | #1A1A24 |
| Surface Variant | #22222F |
| Primary | #818CF8 |
| Primary Container | #3730A3 |
| Text Primary | #F1F1F3 |
| Text Secondary | #9CA3AF |
| Text Muted | #6B7280 |
| Border | #2E2E3E |
| Income | #34D399 |
| Expense | #FB7185 |
| Warning | #FBBF24 |
| Danger | #F87171 |

Use semantic colors consistently.

Green represents income and positive results.

Red represents expenses and negative results.

Orange represents warnings and pending items.

Purple represents the main brand identity.

Never communicate important information through color alone.

## Typography

Use system fonts.

Create a consistent scale:

- Display: 28px, bold.
- Screen title: 22px, bold.
- Section title: 17px, semibold.
- Body: 14–15px.
- Secondary text: 12–13px.
- Small labels: 11–12px.

## Layout

- Use an 8-point spacing system.
- Standard card radius: 16px.
- Input radius: 12px.
- Bottom sheet radius: 20–28px.
- Minimum touch target: 44x44px.

Design specifically for mobile phones.

All screens must adapt to different screen sizes without overflow or clipped content.

---

# 4. APPLICATION STRUCTURE

Use four main navigation destinations:

1. Home.
2. Finance.
3. Orders.
4. Profile.

Add a central floating action button (+).

The bottom navigation should be simple, compact, and consistent.

Use IndexedStack to preserve tab states.

The FAB opens a quick-action menu:

- Add income.
- Add expense.
- Create order.
- Add debt.
- Add customer.

Quick actions must be accessible without complicated navigation.

## Profile navigation

The Profile screen contains:

- User information.
- Customers.
- Debts.
- Monthly reports and periods.
- Settings.
- Theme.
- Language.
- Currency.
- About.
- Logout.

Do not hide essential functionality inside multiple nested menus.

---

# 5. HOME DASHBOARD

The dashboard is the most important screen.

It should communicate the business situation immediately.

Do not overcrowd it.

## Header

Display:

- Greeting or business name.
- Current reporting month.
- Month selection control.
- Notifications.

Example:

October 2026
Business overview

## Main financial card

Create one visually prominent summary.

Display:

- Net profit.
- Total received income.
- Total expenses.

Profit should be the main visual focus.

Allow users to open detailed financial information by tapping the relevant metrics.

## Secondary information

Display a compact selection of:

- Customer outstanding debts.
- Active orders.
- Completed orders.

Avoid repeating the same numbers in multiple places.

## Financial chart

Display income and expenses over time.

Support:

- Current month.
- Previous months.
- Custom date range.

Use meaningful labels and legends.

## Recent activity

Show recent:

- Payments.
- Income.
- Expenses.
- Order updates.
- Debt payments.

Each item should display its date, description, amount, and relevant relationship.

Add a way to view all activity.

## Dashboard behavior

All values must come from actual stored data.

The dashboard must update automatically when relevant records change.

Never use hardcoded financial values.

---

# 6. FINANCE MODULE

Create a clear financial management section.

It should contain:

- Financial overview.
- Income.
- Expenses.
- Transaction history.
- Analytics.

## Financial concepts

Keep these concepts separate:

**Received income:** Money actually received by the business.

**Expenses:** Money actually paid by the business.

**Net cash result:** Received income minus paid expenses.

**Outstanding receivables:** Money customers still owe.

**Payables:** Money the business still owes other people.

Do not confuse the total value of orders with money already received.

## Example

An order is worth $1,000.

The customer pays $300.

The application must display:

- Order value: $1,000.
- Received: $300.
- Outstanding: $700.

Only $300 is counted as received income.

When the remaining $700 is paid, another payment is recorded.

Never count the original order value as received income automatically.

## Transactions

Each transaction must support:

- Unique ID.
- Amount.
- Type: income or expense.
- Category.
- Description.
- Date.
- Optional customer.
- Optional order.
- Optional debt.
- Payment method.
- Notes.
- Creation timestamp.

Users can:

- Add transactions.
- Edit transactions.
- Delete transactions with confirmation.
- Search.
- Filter by date.
- Filter by category.
- Filter by type.
- Open transaction details.

All financial values must use safe monetary calculations.

Use integer minor currency units or an appropriate decimal-safe representation.

Never rely on inaccurate floating-point calculations for money.

---

# 7. MONTHLY PERIOD SYSTEM

This is an important feature.

However, keep it simple.

Periods should primarily work as automatic monthly reporting windows.

Do not make users manually create and maintain every month.

## 7.1 Automatic monthly periods

Automatically organize business activity into calendar months.

Examples:

- October 2026.
- November 2026.
- December 2026.

The current month is the default active reporting period.

Users can switch between months.

Users can also select a custom date range.

## 7.2 What belongs to a month?

Every financial transaction belongs to the month of its actual transaction date.

Example:

A customer pays an old debt in November.

Even if the original debt was created in October, the payment is recorded in November's income.

The original debt creation date remains October.

This distinction is essential.

## 7.3 Monthly report

Each month should display:

- Total received income.
- Total expenses.
- Net cash result.
- Number of new orders.
- Number of completed orders.
- Number of cancelled orders.
- New customers.
- Payments received.
- Outstanding customer debts at the report date.
- Outstanding business payables.

Clearly distinguish between:

- Activity during the selected month.
- Outstanding balances at the current date.
- Outstanding balances at the historical reporting date, if historical snapshots are supported.

Do not mix these concepts.

## 7.4 Month comparison

Allow users to compare:

- Income.
- Expenses.
- Net cash result.
- Orders.
- Customer activity.

Example:

October compared with September.

Display actual differences and percentage changes where meaningful.

Do not display misleading comparisons when one month is incomplete.

## 7.5 Monthly summary

Provide an optional "Monthly Summary" action.

Generate a report showing:

- Financial performance.
- Orders created and completed.
- Customer payments.
- Expenses.
- Outstanding debts.
- Important business activity.

Do not force the user to close a month manually.

Historical records must remain accessible.

## 7.6 Historical data

Changing months must never delete, reset, or move data.

Customers remain global.

Orders remain in their original history.

Debts remain accessible.

Transactions remain associated with their actual dates.

Never transfer unpaid debt into a new month as if it were a new debt.

---

# 8. ORDERS MODULE

Orders represent work or services provided to customers.

Each order should contain:

- Order ID.
- Title.
- Customer.
- Description.
- Total price.
- Amount received.
- Outstanding balance.
- Creation date.
- Due date.
- Status.
- Optional notes.
- Optional images.
- Optional attachments.

## Order statuses

- New.
- In progress.
- Completed.
- Cancelled.

## Order list

Provide:

- Search.
- Status filters.
- Date filters.
- Customer filters.
- Clear payment indicators.
- Quick access to order details.

## Order details

Display:

1. Order information.
2. Customer information.
3. Total order price.
4. Total received.
5. Outstanding balance.
6. Payment history.
7. Order status.
8. Creation date.
9. Deadline.
10. Notes and attachments.

## Payment functionality

Users can record:

- Advance payment.
- Partial payment.
- Final payment.

Every payment must be linked to the order.

When a payment is recorded:

- Update the received amount.
- Update the remaining balance.
- Create the corresponding financial transaction.
- Update the customer balance.
- Update relevant financial analytics.

Do not create duplicate financial records.

Completing an order does not automatically mean it is fully paid.

Cancelling an order must require confirmation and preserve relevant payment history.

If money has already been received, handle refunds through explicit refund transactions rather than silently deleting the payment.

---

# 9. CUSTOMERS MODULE

Customers are global records, not month-specific records.

Each customer contains:

- Name.
- Phone.
- Optional email.
- Notes.
- Creation date.
- Total order value.
- Total received payments.
- Outstanding balance.
- Number of orders.

## Customer profile

Display:

- Customer information.
- Order history.
- Payment history.
- Outstanding debts.
- Total order value.
- Total received.
- Recent activity.

Provide quick actions:

- Create order.
- Record payment.
- Add debt.
- Edit customer.

Allow users to select existing customers when creating orders.

Avoid creating duplicate customer records unnecessarily.

---

# 10. DEBT MANAGEMENT

Create a dedicated debt management section.

Support two types:

## Money owed to me

Customer receivables.

These can originate from:

- Unpaid order balances.
- Manually created debts.

## Money I owe

Business payables.

These represent money owed to:

- Suppliers.
- Individuals.
- Other businesses.

Each standalone debt should contain:

- ID.
- Person or company.
- Debt direction.
- Original amount.
- Amount paid.
- Remaining amount.
- Creation date.
- Due date.
- Description.
- Status.
- Payment history.

## Debt statuses

- Unpaid.
- Partially paid.
- Paid.
- Overdue.

Statuses should update according to payment history and due dates.

## Important debt rules

An unpaid order balance must automatically appear in customer receivables.

Do not create a duplicate standalone debt for the same order balance.

Users must be able to record partial payments.

Each payment updates the outstanding balance.

Never allow a payment to exceed the remaining balance without an explicit overpayment or refund workflow.

Every payment must have a proper financial record.

Debt history must remain available across all reporting months.

---

# 11. FINANCIAL DATA RELATIONSHIPS

The application must operate as one connected business system.

Implement the following workflows.

### Workflow A — New customer

Create a customer.

The customer becomes available when creating future orders.

### Workflow B — New order

Create an order for an existing or new customer.

The order automatically appears in the customer's profile.

### Workflow C — Advance payment

A customer pays $300 toward a $1,000 order.

The order shows:

- Total: $1,000.
- Paid: $300.
- Remaining: $700.

Finance records $300 income.

The outstanding balance becomes $700.

### Workflow D — Final payment

The customer pays another $700.

The order becomes fully paid.

Finance records another $700 income.

Outstanding balance becomes zero.

### Workflow E — Partial standalone debt payment

A customer owes $500 independently of an order.

They pay $200.

The debt now shows:

- Original: $500.
- Paid: $200.
- Remaining: $300.

The payment appears in the financial history.

### Workflow F — New month

November begins.

October records remain unchanged.

November financial reports start from November activity.

Existing customers, orders, and debts remain available.

A payment received in November for an October debt is counted as November income.

All these workflows must work with actual data and persistent storage.

---

# 12. SINGLE-USER ONBOARDING

Create a short, simple first-launch experience.

Ask the user for:

- Business name (optional).
- User name.
- Main currency.
- Preferred language.
- Theme preference.

Do not overwhelm users with unnecessary setup questions.

Allow users to skip optional fields.

After onboarding, show the dashboard.

Provide useful empty states with clear next actions.

Do not insert fake financial records.

---

# 13. SETTINGS

Support:

- Light theme.
- Dark theme.
- System theme.
- Russian language.
- English language.
- Main business currency.
- Date format.
- Number format.
- Notification preferences.
- Application information.
- Data backup and export where supported.

Persist settings.

All text must be localized.

Do not hardcode interface strings inside widgets.

Changing display preferences must never modify historical monetary values.

If currency conversion is not implemented, do not imply that multiple currencies can be converted automatically.

---

# 14. UX AND INTERACTION

## Forms

Use clean, compact forms.

Prefer bottom sheets for simple operations.

Use full screens for complex editing.

Forms should:

- Have clear labels.
- Use appropriate keyboards.
- Validate input.
- Display helpful errors.
- Have sensible defaults.
- Support keyboard navigation.
- Respect safe areas.
- Avoid unnecessary fields.

Hide optional fields behind expandable sections when appropriate.

## Search and filters

Use consistent search and filtering patterns.

Support search in:

- Orders.
- Customers.
- Debts.
- Transactions.

## Feedback

Implement:

- Haptic feedback where appropriate.
- Confirmation sheets for destructive operations.
- Success messages.
- Validation messages.
- Loading states.
- Error states with retry.
- Helpful empty states.

Support swipe actions where appropriate, but always provide visible alternatives.

Respect system Reduce Motion settings.

Avoid infinite decorative animations.

---

# 15. TECHNICAL ARCHITECTURE

Use Flutter and a clean, maintainable architecture.

Preferred technologies:

- Flutter.
- Dart.
- Provider for state management.
- SharedPreferences for lightweight settings.
- fl_chart for charts.
- intl for formatting.
- flutter_slidable for list actions.
- cached_network_image when remote images are required.

Use a local database such as SQLite through a suitable Flutter persistence package if no backend exists.

Do not store the entire business database in SharedPreferences.

## Architecture

Separate:

- Presentation.
- Components.
- Models.
- Domain logic.
- Repositories.
- Services.
- Providers.
- Theme.
- Localization.
- Database.

Keep calculations outside UI widgets.

Use reusable components.

Avoid duplicated business logic.

## Suggested data models

Create appropriate models for:

- UserProfile.
- Customer.
- Order.
- Transaction.
- Debt.
- DebtPayment.
- OrderPayment.
- Category.
- AppSettings.

You may simplify the payment models if a unified payment and transaction architecture is more reliable.

The most important requirement is that one payment must never be counted twice.

## Data integrity

Implement:

- Unique identifiers.
- Proper relationships.
- Monetary precision.
- Input validation.
- Consistent date handling.
- Referential integrity.
- Safe deletion behavior.
- Transaction history.
- Database transactions for operations that update multiple related records.

Do not silently delete financial history.

Use explicit reversal or refund records when correcting financial events.

Support persistent data across application restarts.

---

# 16. DESIGN SYSTEM COMPONENTS

Create reusable components:

- AppButton.
- AppCard.
- AppInput.
- AppSearchBar.
- AppStatusBadge.
- AppChip.
- AppSegmentedControl.
- AppAvatar.
- AppBottomSheet.
- AppConfirmSheet.
- AppEmptyState.
- AppErrorState.
- AppLoadingIndicator.
- AppNavigationBar.
- AppFloatingActionButton.
- FinancialSummaryCard.
- TransactionListItem.
- OrderListItem.
- CustomerListItem.
- DebtListItem.

All components must follow the same design system.

Do not create different visual styles for similar elements.

---

# 17. PERFORMANCE AND ACCESSIBILITY

Ensure:

- Smooth scrolling.
- Efficient list rendering.
- Minimal unnecessary rebuilds.
- Responsive layouts.
- Correct keyboard behavior.
- Correct safe area handling.
- Readable contrast.
- Accessible touch targets.
- Reduced motion support.
- Efficient image loading.

Animations should be restrained:

- 150–250ms.
- EaseOut and easeInOut.
- Opacity and simple transformations.

Avoid excessive gradients, blur, and complex shadows.

---

# 18. DEVELOPMENT PROCESS

Do not immediately start generating random UI files.

Follow a structured development process.

## Phase 1 — Product specification

Define:

- Complete feature list.
- Navigation.
- User journeys.
- Screen responsibilities.
- Data relationships.
- Financial rules.
- Monthly reporting rules.

Identify potential business logic conflicts before coding.

## Phase 2 — UX architecture

Design all screens.

Plan layouts for small phones.

Establish the complete navigation flow.

Create wireframes before implementing complex screens.

## Phase 3 — Design system

Implement:

- Theme.
- Typography.
- Spacing.
- Colors.
- Components.
- Navigation.

## Phase 4 — Data architecture

Implement:

- Database.
- Models.
- Repositories.
- Providers.
- Business calculations.
- Payment relationships.

Test financial calculations before connecting every screen.

## Phase 5 — Core functionality

Implement in this order:

1. Onboarding and settings.
2. Customers.
3. Orders.
4. Order payments.
5. Finance and transactions.
6. Debts and debt payments.
7. Monthly reporting.
8. Dashboard.
9. Analytics.

## Phase 6 — Integration

Verify that all modules communicate correctly.

Test complete business workflows.

## Phase 7 — Polish and QA

Check all screens.

Check both themes.

Check Russian and English.

Check small-screen layouts.

Check all financial calculations.

Check database persistence.

Run:

- flutter analyze.
- flutter test.
- flutter build apk.

Fix errors and important warnings.

---

# 19. REQUIRED TEST SCENARIOS

Do not consider the application complete without testing these scenarios.

### Test 1 — New order

Create a customer and a $1,000 order.

Verify that the order appears in the customer profile.

### Test 2 — Advance payment

Record a $300 payment.

Verify that:

- Income increases by $300.
- Order paid amount becomes $300.
- Outstanding balance becomes $700.

### Test 3 — Final payment

Record another $700.

Verify that:

- Total received becomes $1,000.
- Outstanding balance becomes zero.
- The order is fully paid.

### Test 4 — Partial standalone debt

Create a $500 debt.

Record a $200 payment.

Verify that the remaining debt is $300.

### Test 5 — Expenses

Record a $100 expense.

Verify that the net cash result changes correctly.

### Test 6 — Monthly transition

Create transactions in October and November.

Verify that each month displays its own financial activity.

### Test 7 — Old debt payment

Create a debt in October and pay it in November.

Verify that:

- Debt creation remains associated with October.
- Payment is recorded in November.
- November income is updated.
- Historical October records are not modified.

### Test 8 — Application restart

Close and reopen the application.

Verify that all business records remain available.

### Test 9 — Theme and language

Switch between light and dark themes.

Switch between Russian and English.

Verify that all screens update consistently.

### Test 10 — Editing and deletion

Edit and delete records.

Verify that related financial calculations remain correct.

Never leave orphaned payments or incorrect balances.

---

# 20. FINAL ACCEPTANCE CRITERIA

The application is complete only when:

- All four navigation sections work.
- Every important button performs its intended action.
- Customers, orders, payments, debts, and transactions are connected.
- Financial calculations are accurate.
- Monthly reports use actual transaction dates.
- Outstanding debts remain available across months.
- No duplicate payments are counted.
- All data persists.
- Russian and English work throughout the application.
- Light and dark themes work throughout the application.
- The UI is consistent and professional.
- Screens fit comfortably on mobile devices.
- No essential feature is represented by a fake placeholder.
- Flutter analysis and build checks pass.

If something cannot be completed, clearly document it instead of pretending it works.

---

# FINAL PRODUCT VISION

Business Manager should feel like a personal assistant for someone building a business.

The user opens the application and immediately understands:

- How much money came in.
- How much money went out.
- How much they actually earned.
- How much customers still owe.
- What orders are being worked on.
- What needs attention.

They can add an order in seconds, record a payment, check a customer's history, and understand their monthly business performance without needing accounting knowledge.

The application must be simple on the surface and reliable underneath.

**Build a genuinely useful business management product, not just a beautiful collection of screens.**

Prioritize product thinking, financial correctness, excellent mobile UX, and simplicity above everything else.

Do not stop after creating a specification. Implement the actual application, test its functionality, and verify the final result.


.env file:
MONGODB_URI=mongodb://superprofi331_db_user:Zrl2EEo4nSs6jw5B@ac-txrzaf3-shard-00-00.0rcz2o4.mongodb.net:27017,ac-txrzaf3-shard-00-01.0rcz2o4.mongodb.net:27017,ac-txrzaf3-shard-00-02.0rcz2o4.mongodb.net:27017/business_manager?ssl=true&replicaSet=atlas-vo23lq-shard-0&authSource=admin&retryWrites=true&w=majority
NEXT_PUBLIC_API_URL=http://localhost:3001
JWT_SECRET=biznes_crm_jwt_secret_key_2026_change_in_production_min32chars
JWT_EXPIRES_IN=7d
NODE_ENV=development



https://cdn.dribbble.com/userupload/49191483/file/afefae57b46fce812b7be29f178693b8.png?resize=1448x1086&vertical=center

https://images.openai.com/static-rsc-4/G8_13c7k-T5CznHX6fGd6XMAPn5o33FStdiJTGh7DhNOgVFu8SLNsbE_MZXhQGhT4ITBNKngaHkIFmYgyiyQprXEinxNKBXANo9GRetak6Eo3vES_DufErEQw-MWnQhLdHtBfLgr5INnHAseG5uXuDMFXj2fJL4NvKuk8BiTePQTaeuLCBaIKePWn0G5no6l?purpose=fullsize

https://images.openai.com/static-rsc-4/phcw3ztx2NfkHr2PBgrtFteeu_VW-CU5OUKYPqi0RthV7o3vopL4ih0LytQ3BYiYwTLEtAMCPrcjtj2ogLIOpSZPZGKq2Vd5K8C9yVc1QCNF_j0_3fgx0Ro4RaARtAkt49z7IfD5QvHOBPovHzdPm7vVHvn93VeZCKzfnJ_gveYhqnKDfSepAWHXi1wvyh_A?purpose=fullsize

https://images.openai.com/static-rsc-4/AC6bf0NF5UZs3U_OXYSZ939M4nLCNYOY7P8gt9RMVEkStjjwwhpCsJPENr8b5xCkrI7NeOdG-eTKqElCZdnsCQDxrWwP3sarpFeFngab78BUS1HSTay3EkmttWd_aRRLbrVfK9NZsepu67Vk5fwE5jxURLPnhwgMR9ToZFUUe-rO1a8EwEwGNyh-HAr_nGbe?purpose=fullsize

https://images.openai.com/static-rsc-4/8Ou1wdo0pUjZvIFFQ30Ku3GtvgBBzI6wXPnKi9wAkVJlmjklJ175Z0dlBH8HM1QKWiBT6GN_Dz9cdYp4Yy8gK1ksyActVBO3OZF6fRK58GK3XY6iCh9VIuQQSfJlDPTrTtF_wGw3GUOZwS6oAyBL5iTlNea5WIqkAqO65d9Tw21N9vF6GKGBjW7BYNWBF2xK?purpose=fullsize