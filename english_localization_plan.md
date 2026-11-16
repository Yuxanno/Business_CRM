# План полной локализации приложения на английский язык (RU / EN)

## Цель
Перевести весь пользовательский интерфейс **Business CRM** на английский язык при сохранении русского языка, а также добавить переключатель языка (`RU` / `EN`) в верхнем углу экрана входа и регистрации.

---

## Этап 1. Базовая инфраструктура локализации
- [x] Создать [lib/l10n/app_tr.dart](lib/l10n/app_tr.dart) с реактивным `context.tr(ru, en)`, `context.isEn` и синхронизацией `AppTr.isEn` для сервисов и моделей.
- [x] Синхронизировать `AppTr.isEn` в `lib/main.dart` и `lib/providers/settings_provider.dart`.
- [x] Локализовать даты, месяцы и относительные подписи в `lib/services/date_helper.dart`.
- [x] Локализовать категории транзакций в `lib/models/transaction.dart`.

## Этап 2. Авторизация, регистрация и онбординг
- [x] `lib/screens/auth/login_screen.dart` — добавить кнопку смены языка (`RU` / `EN`) в правом верхнем углу + перевести вход, регистрацию, валидацию и ошибки.
- [x] `lib/components/auth/social_login.dart` — перевести подписи разделителя / соц-кнопок.
- [x] `lib/screens/onboarding/onboarding_screen.dart` — перевести шаги онбординга, поля и кнопки.

## Этап 3. Навигация и общие компоненты (`lib/components/`)
- [x] `lib/screens/shell/app_shell.dart` — перевести нижнее меню (`Главная / Home`, `Деньги / Finance`, `Заказы / Orders`, `Ещё / More`).
- [x] `lib/components/form_widgets.dart` — перевести валидацию суммы, пикеры дат, подсказки.
- [x] `lib/components/app_confirm_sheet.dart`, `app_empty_state.dart`, `app_section_header.dart`, `app_status_badge.dart`.
- [x] `lib/components/finance_bar_chart.dart` — перевести легенду, переключатели, месяцы, тултипы и нижнюю панель инсайтов.
- [x] `lib/components/category_chart_widget.dart` — перевести подписи диаграммы категорий.

## Этап 4. Основные экраны и формы (`lib/screens/`)
- [x] **Главная**: `lib/screens/home/home_screen.dart`
- [x] **Деньги**: `lib/screens/finance/finance_screen.dart`, `transaction_form_screen.dart`
- [x] **Заказы**: `lib/screens/orders/orders_screen.dart`, `order_detail_screen.dart`, `order_form_screen.dart`
- [x] **Клиенты**: `lib/screens/customers/customers_screen.dart`, `customer_detail_screen.dart`, `customer_form_screen.dart`
- [x] **Долги**: `lib/screens/debts/debts_screen.dart`, `debt_detail_screen.dart`, `debt_form_screen.dart`
- [x] **Отчёты**: `lib/screens/reports/reports_screen.dart`, `report_detail_screen.dart`
- [x] **Профиль и настройки**: `lib/screens/profile/profile_screen.dart`, `profile_detail_screen.dart`, `account_store.dart`, `lib/screens/settings/settings_screen.dart`, `categories_screen.dart`
- [x] **Сервисы**: `lib/services/api_client.dart`

## Этап 5. Проверка
- [x] Проверить отсутствие непереведённых кириллических строк в UI.
- [x] Проверить баланс скобок во всех `.dart` файлах `lib/`.
