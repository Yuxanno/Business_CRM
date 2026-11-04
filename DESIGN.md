# BUSINESS MANAGER — COMPLETE UI/UX DESIGN SYSTEM & VISUAL IMPLEMENTATION SPECIFICATION

## 1. YOUR ROLE

Act as a senior Product Designer, UI/UX Architect, and Flutter Design System Engineer.

Your task is to design and implement a complete, consistent, premium-quality mobile interface for **Business Manager**, a personal business management application.

The application helps a single business owner manage:
- Orders and projects.
- Customers.
- Income and expenses.
- Debts and payments.
- Monthly financial performance.
- Business periods and historical reports.
- Business activity and performance.

The product must feel like a professional commercial fintech/CRM application, not a generic Flutter template.

**Your main objective is to create an application that is visually beautiful, extremely easy to understand, practical for everyday use, and comfortable on small mobile screens.**

Do not overload screens with information, unnecessary cards, decorative elements, or complicated navigation.

Prioritize usability over visual decoration.

---

# 2. DESIGN DIRECTION

Use the following visual direction:

**Premium Minimalist Fintech + Modern Business Management.**

Visual characteristics:
- Clean and spacious layouts.
- Soft neutral backgrounds.
- White or dark elevated surfaces.
- Indigo/purple brand accents.
- Emerald green for income and positive financial results.
- Rose/red for expenses and negative financial indicators.
- Amber for warnings and pending payments.
- Subtle borders.
- Minimal shadows.
- Rounded but not excessively rounded components.
- Clear visual hierarchy.
- Consistent spacing.
- Modern typography.
- Professional charts and financial summaries.

The application should feel similar in visual quality to a modern banking application combined with a lightweight business CRM.

Avoid:
- Excessive gradients.
- Glassmorphism.
- Heavy shadows.
- Too many floating cards.
- Oversized empty spaces.
- Tiny text.
- Excessive colors.
- Decorative animations.
- Complicated dashboards.
- Unnecessary nested cards.
- Generic template-like UI.

Do not copy another application's interface. Create an original, cohesive design.

---

# 3. COLOR DESIGN SYSTEM

Create centralized color tokens. Never hardcode colors independently in individual screens.

## 3.1 Brand palette — Indigo

Primary brand color: `#6366F1`

| Token | Color |
|---|---|
| Primary | #6366F1 |
| Primary Dark | #4F46E5 |
| Primary Deep | #4338CA |
| Primary Light | #818CF8 |
| Primary Subtle | #EEF2FF |
| Primary Container | #E0E7FF |
| On Primary | #FFFFFF |

Use indigo for:
- Primary buttons.
- Active navigation.
- Selected tabs.
- Important actions.
- Interactive elements.
- FAB.
- Selected filters.

Do not use primary indigo for every icon and every card.

## 3.2 Light theme

| Token | Color |
|---|---|
| Background | #F7F8FC |
| Surface | #FFFFFF |
| Surface Secondary | #F1F3F9 |
| Surface Elevated | #FFFFFF |
| Primary | #6366F1 |
| Primary Container | #EEF2FF |
| Text Primary | #181A25 |
| Text Secondary | #667085 |
| Text Muted | #98A2B3 |
| Border | #E5E7EB |
| Divider | #EEF0F4 |

## 3.3 Dark theme

| Token | Color |
|---|---|
| Background | #101116 |
| Surface | #191B25 |
| Surface Secondary | #222530 |
| Surface Elevated | #292C39 |
| Primary | #818CF8 |
| Primary Container | #292B50 |
| Text Primary | #F3F4F6 |
| Text Secondary | #A1A1B2 |
| Text Muted | #74788B |
| Border | #303341 |
| Divider | #282B36 |

Dark mode must be carefully designed, not simply a light theme with inverted colors.

Maintain readable contrast, comfortable surfaces, and clear separation between sections.

## 3.4 Financial semantic colors

These colors must remain consistent throughout the entire application.

### Income — Emerald

- Main: `#10B981`
- Light: `#34D399`
- Dark: `#059669`
- Background: `#D1FAE5`

Used for:
- Received payments.
- Income transactions.
- Positive profit.
- Completed financial operations.

### Expenses — Rose

- Main: `#F43F5E`
- Light: `#FB7185`
- Dark: `#E11D48`
- Background: `#FFE4E6`

Used for:
- Expenses.
- Outgoing payments.
- Negative financial results.

### Warnings — Amber

- Main: `#F59E0B`
- Light: `#FBBF24`
- Dark: `#D97706`
- Background: `#FEF3C7`

Used for:
- Unpaid orders.
- Pending payments.
- Upcoming deadlines.
- Attention-required states.

### Neutral — Slate

Use:
- #F8FAFC
- #F1F5F9
- #E2E8F0
- #CBD5E1
- #94A3B8
- #64748B
- #475569
- #1E293B

Use these for secondary information, neutral statuses, borders, and inactive elements.

---

# 4. STATUS DESIGN SYSTEM

Create reusable status badges.

All statuses must look identical wherever they appear in the application.

| Status | Color |
|---|---|
| New | Indigo |
| In Progress | Blue |
| Completed | Emerald |
| Cancelled | Slate |
| Unpaid | Amber |
| Partially Paid | Orange |
| Paid | Emerald |
| Overdue | Rose |

Use compact pill-shaped badges with subtle backgrounds.

Status must always be understandable through text, not color alone.

Support RU and EN translations.

---

# 5. TYPOGRAPHY SYSTEM

Use native system fonts:
- SF Pro on iOS.
- Roboto on Android.

Do not introduce custom fonts unless there is a strong technical reason.

Typography specifications:

| Element | Size | Weight |
|---|---:|---|
| Large financial value | 30–32px | Bold |
| Screen title | 23–24px | Bold |
| Section heading | 17–18px | Semibold |
| Card title | 15–16px | Semibold |
| Main body | 14–15px | Regular |
| Secondary text | 12–13px | Regular |
| Captions | 11px | Medium |
| Financial card values | 16–20px | Semibold |

Rules:
- Use tabular figures for financial values.
- Avoid excessive font-weight variations.
- Maintain consistent line heights.
- Never make text unnecessarily small to fit more content.
- Support system font scaling.
- Ensure long numbers and currencies remain readable.

---

# 6. SPACING SYSTEM

Use a centralized 4px-based spacing system.

| Token | Value |
|---|---:|
| XS | 4px |
| SM | 8px |
| MD | 12px |
| LG | 16px |
| XL | 20px |
| XXL | 24px |
| XXXL | 32px |

Screen horizontal padding:
- Standard mobile: 20px.
- Compact devices: adapt without overflow.
- Large devices: use a reasonable maximum content width.

Maintain consistent spacing between:
- Screen sections.
- Card contents.
- List items.
- Form fields.
- Buttons.
- Headings.

Do not use arbitrary spacing values throughout the application.

---

# 7. BORDER RADIUS SYSTEM

| Component | Radius |
|---|---:|
| Small elements | 8px |
| Input fields | 12px |
| Buttons | 12–14px |
| Chips | 10–12px |
| Standard cards | 16px |
| Large summary cards | 20px |
| Bottom sheets | 24px top corners |
| Large modal surfaces | 24px |

Avoid excessive rounding that makes the application look childish.

---

# 8. COMPONENT DESIGN SYSTEM

Create reusable components and use them consistently.

Required components:

- AppButton
- AppCard
- AppListItem
- AppSearchBar
- AppChip
- AppStatusBadge
- AppAvatar
- AppSheet
- AppEmptyState
- AppErrorState
- AppLoadingIndicator
- AppSkeleton
- AppConfirmSheet
- AppSegmentedControl
- AppBottomNavigation
- AppFAB
- AppFinancialSummary
- AppStatCard
- AppSectionHeader
- AppTransactionItem
- AppOrderCard
- AppDebtCard
- AppCustomerCard
- AppFilterBar

Every component must support light and dark themes.

Do not duplicate component implementations across different screens.

## Card design rules

- Standard card radius: 16px.
- White surface in light mode.
- Dark elevated surface in dark mode.
- Subtle border.
- Minimal shadow.
- Consistent internal padding.
- Clear hierarchy between title, value, and description.

Do not place multiple unnecessary cards inside each other.

Use cards only when they improve information organization.

---

# 9. BUTTON DESIGN SYSTEM

Create five button variants:

1. Primary — main action.
2. Secondary — secondary action.
3. Outline — alternative action.
4. Text — lightweight actions.
5. Danger — destructive actions.

Minimum height: 48px.

Every button must support:
- Normal.
- Pressed.
- Disabled.
- Loading.

Primary buttons use indigo with white text.

Danger buttons use restrained red styling.

Maintain minimum touch targets of 44x44px.

---

# 10. NAVIGATION DESIGN

Use a simple bottom navigation with four main sections:

1. Home.
2. Finance.
3. Orders.
4. Profile.

Use a central floating action button for quick creation.

Navigation requirements:
- Consistent icons.
- Short labels.
- Clearly visible selected state.
- SafeArea support.
- No content hidden behind navigation.
- Smooth and lightweight transitions.
- Preserve screen state when switching tabs using IndexedStack.

The FAB should adapt to the active section.

For example:
- Home: quick creation menu.
- Finance: add transaction.
- Orders: add order.
- Profile: optional quick action or hidden if unnecessary.

The FAB must never obstruct important content or controls.

Debts, Customers, and Periods must remain accessible through clear navigation paths from Profile and relevant dashboard sections.

Do not hide important functionality behind confusing menus.

---

# 11. DASHBOARD DESIGN

The dashboard should answer three questions immediately:

1. How much money did the business earn?
2. How much did the business spend?
3. How much profit did the business generate?

The dashboard should be analytical, not overloaded.

Recommended layout:

### Header
- Greeting or business title.
- Active period selector.
- Notification button.

### Financial overview
One main financial summary containing:
- Total income.
- Total expenses.
- Net profit.

Clearly distinguish received money from unpaid order amounts.

### Key statistics
Compact statistics:
- Active orders.
- Outstanding debts.
- Customers.
- Completed orders.

Do not show too many statistics at once.

### Financial chart
Show income and expenses over time.

Allow changing the interval:
- Week.
- Month.
- 6 months.
- Year.

### Recent activity
Show recent:
- Orders.
- Payments.
- Transactions.

Provide clear navigation to full lists.

The dashboard must prioritize the most important financial information.

Avoid displaying the same number in multiple cards without a clear reason.

---

# 12. FINANCIAL UI DESIGN

Finance screens must be easy to understand.

Separate:
- Income.
- Expenses.
- Profit.
- Customer payments.
- Business expenses.
- Refunds.
- Outstanding receivables.

Use clear financial labels.

Never confuse:
- Order value.
- Money actually received.
- Remaining amount.
- Business profit.
- Cash flow.

Money values must use consistent formatting and the selected business currency.

Use appropriate negative-value formatting.

Create readable transaction rows with:
- Category or icon.
- Description.
- Date.
- Amount.
- Transaction type.

Use green for income and red for expenses.

Do not use color as the only indicator.

---

# 13. ORDERS UI DESIGN

Orders screen should prioritize quick scanning and management.

Each order card should display only essential information:

- Order title.
- Customer name.
- Order amount.
- Payment progress.
- Order status.
- Creation date or deadline.

Payment progress must be visually clear.

The order details screen should contain:
- Complete order information.
- Customer details.
- Financial information.
- Payment history.
- Attached photos.
- Audio notes, if supported.
- Status management.
- Edit and delete actions.

Use a compact card design.

Avoid excessive information in the main order list.

---

# 14. DEBTS UI DESIGN

The debts section must be easy to understand.

Use two clearly separated tabs:

- Owed to me.
- I owe.

At the top, show compact summary values.

Each debt card should contain:
- Person or customer.
- Original amount.
- Amount paid.
- Remaining amount.
- Due date.
- Payment status.

Make overdue debts visually distinguishable.

Debt details should show payment history and remaining balance.

Support partial payments.

Make adding a payment a simple and obvious action.

---

# 15. CUSTOMERS UI DESIGN

Customers screen should feel like a lightweight CRM.

Each customer item should display:
- Avatar or initials.
- Customer name.
- Phone number, if available.
- Number of orders.
- Outstanding balance, if any.

Customer details should provide:
- Contact information.
- Order history.
- Payment history.
- Outstanding debts.
- Financial relationship with the customer.

Avoid turning the customer profile into a complicated administrative page.

Use clear sections and logical grouping.

---

# 16. PERIODS AND ANALYTICS UI DESIGN

Periods must be visually and functionally meaningful.

The active period should be visible in the dashboard.

Provide:
- Current period.
- Previous periods.
- Start and end dates.
- Period income.
- Period expenses.
- Period profit.
- Number of orders.
- Completed orders.
- Outstanding receivables.

Historical periods must remain accessible.

Allow users to compare financial results between periods.

Clearly distinguish active and archived periods.

Do not present periods as simple labels without practical functionality.

Make period selection intuitive.

Use a compact period selector rather than taking up excessive screen space.

---

# 17. PROFILE AND SETTINGS DESIGN

Profile should be clean and organized.

Include:

### Business information
- Business name.
- Owner information.
- Default currency.
- Business details.

### Management
- Customers.
- Debts.
- Periods.
- Reports.

### Preferences
- Light / Dark / System theme.
- RU / EN language.
- Notification settings.

### Application
- Version.
- About.
- Logout.

Use grouped settings sections with clear icons and short descriptions.

Avoid excessive nested menus.

---

# 18. CHART DESIGN SYSTEM

Use fl_chart.

Chart colors:
- Income: #10B981.
- Expenses: #F43F5E.
- Profit: #6366F1.
- Neutral: #94A3B8.

Chart requirements:
- Clean axes.
- Minimal grid lines.
- Readable labels.
- Touch tooltips.
- Correct scaling.
- Light and dark theme support.
- Proper empty states.
- No misleading visualizations.

Never display fake or placeholder financial data as real data.

If there is insufficient data, show a useful empty state explaining what information is needed.

Do not display meaningless charts containing only decorative bars.

---

# 19. ICONOGRAPHY

Use Lucide Icons or Material Symbols Rounded.

Maintain one consistent icon style throughout the application.

Recommended sizes:
- 16px: inline and captions.
- 20px: list items.
- 24px: primary interface actions.
- 28px: major actions and FAB.

Avoid mixing filled, outline, and multicolor icon styles unnecessarily.

Icons must be recognizable and intuitive.

---

# 20. ANIMATION SYSTEM

Use only subtle functional animations.

| Interaction | Duration |
|---|---:|
| Button press | 120–150ms |
| Tab transition | 150ms |
| Screen transition | 180–220ms |
| Small appearance | 150–200ms |
| Bottom sheet | Native Flutter animation |

Use:
- Opacity.
- Scale.
- Small translation.

Avoid:
- Infinite decorative animations.
- Moving gradients.
- Complex blur.
- Heavy parallax.
- Excessive bounce effects.

Respect Reduce Motion accessibility settings.

When reduced motion is enabled, use immediate or simplified transitions.

---

# 21. MOBILE RESPONSIVENESS

The application is primarily designed for mobile phones.

Test the interface at:
- 320px.
- 360px.
- 390px.
- 430px.

Mandatory requirements:

- SafeArea on relevant screens.
- No horizontal overflow.
- No clipped financial values.
- No overlapping widgets.
- No hidden buttons.
- Scrollable forms.
- Correct keyboard behavior.
- Correct bottom navigation positioning.
- Proper handling of long customer names.
- Proper handling of large currency amounts.
- Support for system font scaling.
- Minimum 44x44px touch targets.

On narrow screens, use compact cards instead of horizontal tables.

Do not make text smaller simply to fit more information.

---

# 22. EMPTY, LOADING, AND ERROR STATES

Every data-driven screen must have three properly designed states.

### Empty state

Explain:
- What this section is for.
- Why there is currently no data.
- What the user can do next.

Provide a clear action button when appropriate.

### Loading state

Use static skeleton placeholders by default.

Do not use infinite shimmer animations.

### Error state

Display:
- Simple explanation.
- Retry button.
- Appropriate visual indication.

Do not leave blank screens when something goes wrong.

---

# 23. MICROINTERACTIONS AND FEEDBACK

Add subtle haptic feedback to important actions where supported.

Provide feedback for:
- Successful creation.
- Successful editing.
- Successful payment registration.
- Deletion.
- Validation errors.
- Status changes.

Use confirmation bottom sheets for destructive operations.

Avoid unnecessary confirmation dialogs for routine actions.

All interactions must provide clear feedback.

---

# 24. DESIGN QUALITY RULES

These rules are mandatory:

1. Do not overcrowd screens.
2. Do not display every available statistic on the dashboard.
3. Do not repeat the same information unnecessarily.
4. Do not use tiny typography.
5. Do not create unnecessary nested cards.
6. Do not use excessive colors.
7. Do not use gradients as a default decoration.
8. Do not use heavy shadows.
9. Do not hide important actions.
10. Do not sacrifice functionality for visual appearance.
11. Do not make screens unnecessarily tall through excessive padding.
12. Do not make every component visually identical when its purpose differs.
13. Do not introduce inconsistent spacing or typography.
14. Do not leave any screen using an outdated visual style.
15. Do not implement only the dashboard while leaving secondary screens unfinished.

Every screen must look like part of the same professionally designed application.

---

# 25. IMPLEMENTATION REQUIREMENTS

Translate this design system into reusable Flutter code.

Recommended architecture:

- `lib/theme/app_colors.dart`
- `lib/theme/app_spacing.dart`
- `lib/theme/app_typography.dart`
- `lib/theme/app_theme.dart`
- `lib/theme/theme_provider.dart`

Components:

- `lib/components/app_button.dart`
- `lib/components/app_card.dart`
- `lib/components/app_list_item.dart`
- `lib/components/app_search_bar.dart`
- `lib/components/app_chip.dart`
- `lib/components/app_sheet.dart`
- `lib/components/app_status_badge.dart`
- `lib/components/app_avatar.dart`
- `lib/components/app_empty_state.dart`
- `lib/components/app_error_state.dart`
- `lib/components/app_skeleton.dart`
- `lib/components/app_confirm_sheet.dart`
- `lib/components/app_segmented_control.dart`
- `lib/components/app_nav_bar.dart`
- `lib/components/app_fab.dart`

Use ThemeExtension or an equally maintainable approach for semantic colors.

All components must obtain their colors and typography from the centralized design system.

Do not hardcode styling values inside individual screens.

Preserve the existing application business logic and data integrity when implementing the visual redesign.

---

# 26. REQUIRED DESIGN AND IMPLEMENTATION WORKFLOW

Follow this workflow instead of immediately modifying random widgets.

### Phase 1 — Product and UX analysis

Analyze every application screen and identify:
- Its main purpose.
- Most important user action.
- Information hierarchy.
- Navigation relationships.
- Redundant information.
- UX problems.

### Phase 2 — Design system

Implement:
- Light theme.
- Dark theme.
- Typography.
- Spacing.
- Colors.
- Radius.
- Component standards.
- Interaction states.

### Phase 3 — Screen design

Design all screens using the same system.

Do not leave secondary screens with old styles.

Ensure the visual hierarchy is correct on every screen.

### Phase 4 — Flutter implementation

Build reusable components and apply them across the application.

Keep the architecture maintainable.

### Phase 5 — Responsive refinement

Test all screens on different mobile widths.

Fix overflow, clipping, keyboard issues, and navigation problems.

### Phase 6 — Quality assurance

Verify:
- Both themes.
- All screens.
- All forms.
- All buttons.
- All navigation.
- All empty states.
- All loading states.
- All error states.
- Financial value formatting.
- Accessibility.
- Reduce Motion.

Run `flutter analyze` and fix all errors introduced by the implementation.

Run `flutter build apk` and fix build errors.

---

# 27. FINAL ACCEPTANCE CRITERIA

The redesign is NOT complete unless:

- Every screen follows the same design system.
- Light and dark themes are fully implemented.
- Dashboard is clear and not overloaded.
- Orders, finances, debts, customers, and periods are easy to navigate.
- Financial values are immediately understandable.
- Components are reusable.
- Mobile layouts work without overflow.
- Forms work correctly with the keyboard.
- Buttons and actions provide feedback.
- Empty and error states are properly designed.
- No screen looks unfinished.
- No placeholder interface remains.
- Existing business functionality is preserved.
- The application builds successfully.

**FINAL DESIGN PRINCIPLE:**

Create a professional business management application that a beginner business owner can understand and use immediately, without needing to learn complicated accounting software.

The interface must make business management feel simple, organized, and transparent.

A user should be able to open the application, understand their financial situation in seconds, add an order in a few taps, register a payment easily, and see how their business is performing over time.

**Do not build an application that merely looks modern. Build one that is genuinely easy and pleasant to use every day.**