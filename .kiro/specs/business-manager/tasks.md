# Implementation Plan: Business Manager

## Overview

Business Manager — мобильное Flutter-приложение для управления малым бизнесом. Локальная SQLite база, Provider state management, Go Router навигация. Язык: русский / английский.

## Task Dependency Graph

```
Фаза 1 → Фаза 2 → Фаза 3 → Фаза 4 → Фаза 5 → Фаза 6
  → Фаза 7 → Фаза 8 → Фаза 9 → Фаза 10 → Фаза 11
  → Фаза 12 → Фаза 13 → Фаза 14 → Фаза 15
```

## Tasks

### ФАЗА 1 — Инициализация проекта Flutter

- [x] **Задача 1.1** — Создать Flutter-проект
- [x] **Задача 1.2** — Настроить `pubspec.yaml` (provider, sqflite, shared_preferences, fl_chart, intl, flutter_slidable, uuid, go_router)
- [x] **Задача 1.3** — Настроить структуру папок (`lib/`: theme / components / models / repositories / providers / services / screens / l10n)

---

### ФАЗА 2 — Дизайн-система

- [x] **Задача 2.1** — `app_colors.dart` — все токены светлой/тёмной темы, ThemeExtension
- [x] **Задача 2.2** — `app_spacing.dart` + `app_typography.dart`
- [x] **Задача 2.3** — `app_theme.dart` — ThemeData light/dark
- [x] **Задача 2.4** — `theme_provider.dart`

---

### ФАЗА 3 — Базовые компоненты UI

- [x] **Задача 3.1** — `AppButton` (primary, secondary, outline, text, danger)
- [x] **Задача 3.2** — `AppCard` + `AppSummaryCard`
- [x] **Задача 3.3** — `AppSearchBar` + `AppFilterChip`
- [x] **Задача 3.4** — `AppStatusBadge` + `AppAvatar`
- [x] **Задача 3.5** — `AppConfirmSheet`
- [x] **Задача 3.6** — `AppEmptyState` + `AppErrorState`
- [x] **Задача 3.7** — `AppSectionHeader` + `AppShell` с Bottom Nav + FAB

---

### ФАЗА 4 — База данных и модели данных

- [x] **Задача 4.1** — `DatabaseService` (sqflite, 6 таблиц, индексы, foreign keys)
- [x] **Задача 4.2** — Модели: `AppSettings`
- [x] **Задача 4.3** — Модели: `Customer`
- [x] **Задача 4.4** — Модели: `Order`, `OrderPayment`
- [x] **Задача 4.5** — Модели: `AppTransaction`, `TransactionCategories`
- [x] **Задача 4.6** — Модели: `Debt`, `DebtPayment`
- [x] **Задача 4.7** — `FinancialCalculator` + `DateHelper`

---

### ФАЗА 5 — Репозитории и провайдеры

- [x] **Задача 5.1** — `SettingsRepository` + `SettingsProvider`
- [x] **Задача 5.2** — `CustomerRepository` + `CustomerProvider`
- [x] **Задача 5.3** — `OrderRepository` + `OrderProvider`
- [x] **Задача 5.4** — `TransactionRepository` + `FinanceProvider`
- [x] **Задача 5.5** — `DebtRepository` + `DebtProvider`
- [x] **Задача 5.6** — `DashboardProvider`

---

### ФАЗА 6 — Локализация

- [x] **Задача 6.1** — Настроить `flutter_localizations`
- [x] **Задача 6.2** — `app_ru.arb`
- [x] **Задача 6.3** — `app_en.arb`

---

### ФАЗА 7 — Онбординг и настройки

- [x] **Задача 7.1** — `OnboardingScreen` (имя, валюта, язык, тема)
- [x] **Задача 7.2** — Логика первого запуска (GoRouter redirect)
- [x] **Задача 7.3** — `SettingsScreen` (тема, язык, валюта, профиль)

---

### ФАЗА 8 — Навигация и shell-экран

- [x] **Задача 8.1** — `AppShell` с Bottom Navigation
- [x] **Задача 8.2** — Центральный FAB с быстрым меню действий
- [x] **Задача 8.3** — GoRouter конфигурация (все роуты)

---

### ФАЗА 9 — Клиенты

- [x] **Задача 9.1** — `CustomersScreen` — список с поиском, swipe-to-delete
- [x] **Задача 9.2** — `CustomerFormScreen` — форма создания/редактирования
- [x] **Задача 9.3** — `CustomerDetailScreen` — профиль, заказы, статистика

---

### ФАЗА 10 — Заказы

- [x] **Задача 10.1** — `OrdersScreen` — список с фильтрами по статусу, поиском
- [x] **Задача 10.2** — `OrderFormScreen` — форма создания/редактирования
- [x] **Задача 10.3** — `OrderDetailScreen` — детали, финансовый прогресс
- [x] **Задача 10.4** — Запись платежа по заказу (bottom sheet)
- [x] **Задача 10.5** — История платежей по заказу
- [x] **Задача 10.6** — Смена статуса заказа с подтверждением для отмены

---

### ФАЗА 11 — Финансы

- [x] **Задача 11.1** — `FinanceScreen` — обзор за период, навигация по месяцам
- [x] **Задача 11.2** — Список транзакций с группировкой по дате, фильтры по типу
- [x] **Задача 11.3** — `TransactionFormScreen` — форма добавления/редактирования
- [x] **Задача 11.4** — Аналитика по категориям (pie chart + список) — `CategoryChartWidget`
- [x] **Задача 11.5** — График доходов и расходов (fl_chart, линейный/барный)

---

### ФАЗА 12 — Долги

- [x] **Задача 12.1** — `DebtsScreen` — два таба: мне / я, сводный баннер
- [x] **Задача 12.2** — `DebtFormScreen` — форма создания/редактирования
- [x] **Задача 12.3** — `DebtDetailScreen` — детали, история платежей
- [x] **Задача 12.4** — Запись частичного платежа по долгу

---

### ФАЗА 13 — Dashboard (главный экран)

- [x] **Задача 13.1** — Хедер (приветствие, выбор месяца)
- [x] **Задача 13.2** — Главная финансовая карточка (прибыль / доходы / расходы)
- [x] **Задача 13.3** — Быстрая статистика (заказы, долги, клиенты)
- [x] **Задача 13.4** — График за период на главном экране (fl_chart, барный)
- [x] **Задача 13.5** — Последние активности (транзакции)

---

### ФАЗА 14 — Профиль и отчётность

- [x] **Задача 14.1** — `ProfileScreen` (данные бизнеса, разделы навигации)
- [x] **Задача 14.2** — Месячные отчёты — `ReportsScreen` (список 12 мес.)
- [x] **Задача 14.3** — `ReportDetailScreen` (сводка + графики + категории)---

### ФАЗА 15 — Интеграция и финальная QA

- [x] **Задача 15.1** — Проверить все связи: заказ → платёж → транзакция → клиент
- [x] **Задача 15.2** — Проверить месячные периоды
- [x] **Задача 15.3** — Проверить обе темы на всех экранах
- [x] **Задача 15.4** — Проверить оба языка (RU / EN)
- [x] **Задача 15.5** — Проверить layout на разных экранах
- [x] **Задача 15.6** — `flutter analyze` — нет errors, только deprecation infos (withOpacity → withValues, go_router __)
- [ ] **Задача 15.7** — `flutter build apk` — запустить финальную сборку

---

## Notes

- Все денежные операции только в integer cents (никаких float)
- Платёж по заказу/долгу автоматически создаёт транзакцию
- Исторические данные неизменяемы при смене периода
- Транзакции привязаны к месяцу своей даты
- Дизайн-система: indigo primary, green income, rose expense, amber warning
- **Активная задача:** Задача 15.7 — `flutter build apk`
