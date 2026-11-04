# Business Manager — Дизайн-система

## Цветовая палитра

### Светлая тема
| Токен | Значение |
|---|---|
| Background | #F7F8FC |
| Surface | #FFFFFF |
| Surface Secondary | #F1F3F9 |
| Primary | #6366F1 |
| Primary Container | #EEF2FF |
| Text Primary | #181A25 |
| Text Secondary | #667085 |
| Text Muted | #98A2B3 |
| Border | #E5E7EB |
| Income | #10B981 |
| Expense | #F43F5E |
| Warning | #F59E0B |

### Тёмная тема
| Токен | Значение |
|---|---|
| Background | #101116 |
| Surface | #191B25 |
| Surface Secondary | #222530 |
| Primary | #818CF8 |
| Primary Container | #292B50 |
| Text Primary | #F3F4F6 |
| Text Secondary | #A1A1B2 |
| Border | #303341 |
| Income | #34D399 |
| Expense | #FB7185 |
| Warning | #FBBF24 |

## Типографика
- Display: 30–32px bold
- Screen title: 23–24px bold
- Section heading: 17–18px semibold
- Card title: 15–16px semibold
- Body: 14–15px regular
- Secondary: 12–13px regular
- Caption: 11px medium

## Отступы (4px grid)
- XS: 4 / SM: 8 / MD: 12 / LG: 16 / XL: 20 / XXL: 24 / XXXL: 32

## Радиусы
- Input: 12px
- Card: 16px
- Large card: 20px
- Bottom sheet: 24px (верх)
- Button: 12–14px

## Статусы заказов
| Статус | Цвет |
|---|---|
| Новый | Indigo |
| В работе | Blue |
| Завершён | Emerald |
| Отменён | Slate |
| Не оплачен | Amber |
| Частично оплачен | Orange |
| Оплачен | Emerald |
| Просрочен | Rose |

## Файловая структура
```
lib/
  theme/
    app_colors.dart
    app_spacing.dart
    app_typography.dart
    app_theme.dart
    theme_provider.dart
  components/
    app_button.dart
    app_card.dart
    app_list_item.dart
    app_search_bar.dart
    app_chip.dart
    app_sheet.dart
    app_status_badge.dart
    app_avatar.dart
    app_empty_state.dart
    app_error_state.dart
    app_skeleton.dart
    app_confirm_sheet.dart
    app_segmented_control.dart
    app_nav_bar.dart
    app_fab.dart
  models/
    user_profile.dart
    customer.dart
    order.dart
    transaction.dart
    debt.dart
    debt_payment.dart
    order_payment.dart
    category.dart
    app_settings.dart
  repositories/
    customer_repository.dart
    order_repository.dart
    transaction_repository.dart
    debt_repository.dart
    settings_repository.dart
  providers/
    customer_provider.dart
    order_provider.dart
    finance_provider.dart
    debt_provider.dart
    settings_provider.dart
    dashboard_provider.dart
  services/
    database_service.dart
    financial_calculator.dart
    date_helper.dart
  screens/
    onboarding/
    home/
    finance/
    orders/
    customers/
    debts/
    profile/
    settings/
  l10n/
    app_ru.arb
    app_en.arb
```
