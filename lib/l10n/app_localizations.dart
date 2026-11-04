import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'Бизнес Менеджер'**
  String get appTitle;

  /// No description provided for @appName.
  ///
  /// In ru, this message translates to:
  /// **'Business Manager'**
  String get appName;

  /// No description provided for @nav_home.
  ///
  /// In ru, this message translates to:
  /// **'Главная'**
  String get nav_home;

  /// No description provided for @nav_finance.
  ///
  /// In ru, this message translates to:
  /// **'Финансы'**
  String get nav_finance;

  /// No description provided for @nav_orders.
  ///
  /// In ru, this message translates to:
  /// **'Заказы'**
  String get nav_orders;

  /// No description provided for @nav_profile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get nav_profile;

  /// No description provided for @greeting_morning.
  ///
  /// In ru, this message translates to:
  /// **'Доброе утро'**
  String get greeting_morning;

  /// No description provided for @greeting_day.
  ///
  /// In ru, this message translates to:
  /// **'Добрый день'**
  String get greeting_day;

  /// No description provided for @greeting_evening.
  ///
  /// In ru, this message translates to:
  /// **'Добрый вечер'**
  String get greeting_evening;

  /// No description provided for @income.
  ///
  /// In ru, this message translates to:
  /// **'Доходы'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In ru, this message translates to:
  /// **'Расходы'**
  String get expense;

  /// No description provided for @profit.
  ///
  /// In ru, this message translates to:
  /// **'Прибыль'**
  String get profit;

  /// No description provided for @balance.
  ///
  /// In ru, this message translates to:
  /// **'Баланс'**
  String get balance;

  /// No description provided for @outstanding.
  ///
  /// In ru, this message translates to:
  /// **'Долг'**
  String get outstanding;

  /// No description provided for @received.
  ///
  /// In ru, this message translates to:
  /// **'Получено'**
  String get received;

  /// No description provided for @remaining.
  ///
  /// In ru, this message translates to:
  /// **'Остаток'**
  String get remaining;

  /// No description provided for @status_new.
  ///
  /// In ru, this message translates to:
  /// **'Новый'**
  String get status_new;

  /// No description provided for @status_in_progress.
  ///
  /// In ru, this message translates to:
  /// **'В работе'**
  String get status_in_progress;

  /// No description provided for @status_completed.
  ///
  /// In ru, this message translates to:
  /// **'Завершён'**
  String get status_completed;

  /// No description provided for @status_cancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменён'**
  String get status_cancelled;

  /// No description provided for @status_unpaid.
  ///
  /// In ru, this message translates to:
  /// **'Не оплачен'**
  String get status_unpaid;

  /// No description provided for @status_partially_paid.
  ///
  /// In ru, this message translates to:
  /// **'Частично'**
  String get status_partially_paid;

  /// No description provided for @status_paid.
  ///
  /// In ru, this message translates to:
  /// **'Оплачен'**
  String get status_paid;

  /// No description provided for @status_overdue.
  ///
  /// In ru, this message translates to:
  /// **'Просрочен'**
  String get status_overdue;

  /// No description provided for @orders.
  ///
  /// In ru, this message translates to:
  /// **'Заказы'**
  String get orders;

  /// No description provided for @order.
  ///
  /// In ru, this message translates to:
  /// **'Заказ'**
  String get order;

  /// No description provided for @new_order.
  ///
  /// In ru, this message translates to:
  /// **'Новый заказ'**
  String get new_order;

  /// No description provided for @order_title.
  ///
  /// In ru, this message translates to:
  /// **'Название заказа'**
  String get order_title;

  /// No description provided for @order_price.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость'**
  String get order_price;

  /// No description provided for @order_description.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get order_description;

  /// No description provided for @order_notes.
  ///
  /// In ru, this message translates to:
  /// **'Заметки'**
  String get order_notes;

  /// No description provided for @order_deadline.
  ///
  /// In ru, this message translates to:
  /// **'Дедлайн'**
  String get order_deadline;

  /// No description provided for @order_customer.
  ///
  /// In ru, this message translates to:
  /// **'Клиент'**
  String get order_customer;

  /// No description provided for @order_payments.
  ///
  /// In ru, this message translates to:
  /// **'Платежи по заказу'**
  String get order_payments;

  /// No description provided for @record_payment.
  ///
  /// In ru, this message translates to:
  /// **'Записать платёж'**
  String get record_payment;

  /// No description provided for @payment_amount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма платежа'**
  String get payment_amount;

  /// No description provided for @customers.
  ///
  /// In ru, this message translates to:
  /// **'Клиенты'**
  String get customers;

  /// No description provided for @customer.
  ///
  /// In ru, this message translates to:
  /// **'Клиент'**
  String get customer;

  /// No description provided for @new_customer.
  ///
  /// In ru, this message translates to:
  /// **'Новый клиент'**
  String get new_customer;

  /// No description provided for @customer_name.
  ///
  /// In ru, this message translates to:
  /// **'Имя клиента'**
  String get customer_name;

  /// No description provided for @customer_phone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get customer_phone;

  /// No description provided for @customer_email.
  ///
  /// In ru, this message translates to:
  /// **'Email'**
  String get customer_email;

  /// No description provided for @customer_notes.
  ///
  /// In ru, this message translates to:
  /// **'Заметки'**
  String get customer_notes;

  /// No description provided for @customer_orders.
  ///
  /// In ru, this message translates to:
  /// **'Заказы клиента'**
  String get customer_orders;

  /// No description provided for @debts.
  ///
  /// In ru, this message translates to:
  /// **'Долги'**
  String get debts;

  /// No description provided for @debt.
  ///
  /// In ru, this message translates to:
  /// **'Долг'**
  String get debt;

  /// No description provided for @new_debt.
  ///
  /// In ru, this message translates to:
  /// **'Новый долг'**
  String get new_debt;

  /// No description provided for @owed_to_me.
  ///
  /// In ru, this message translates to:
  /// **'Мне должны'**
  String get owed_to_me;

  /// No description provided for @i_owe.
  ///
  /// In ru, this message translates to:
  /// **'Я должен'**
  String get i_owe;

  /// No description provided for @debt_person.
  ///
  /// In ru, this message translates to:
  /// **'Кому / От кого'**
  String get debt_person;

  /// No description provided for @debt_amount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма'**
  String get debt_amount;

  /// No description provided for @debt_description.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get debt_description;

  /// No description provided for @debt_due_date.
  ///
  /// In ru, this message translates to:
  /// **'Срок'**
  String get debt_due_date;

  /// No description provided for @transactions.
  ///
  /// In ru, this message translates to:
  /// **'Транзакции'**
  String get transactions;

  /// No description provided for @transaction.
  ///
  /// In ru, this message translates to:
  /// **'Транзакция'**
  String get transaction;

  /// No description provided for @new_transaction.
  ///
  /// In ru, this message translates to:
  /// **'Новая транзакция'**
  String get new_transaction;

  /// No description provided for @transaction_amount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма'**
  String get transaction_amount;

  /// No description provided for @transaction_category.
  ///
  /// In ru, this message translates to:
  /// **'Категория'**
  String get transaction_category;

  /// No description provided for @transaction_description.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get transaction_description;

  /// No description provided for @transaction_date.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get transaction_date;

  /// No description provided for @transaction_type_income.
  ///
  /// In ru, this message translates to:
  /// **'Доход'**
  String get transaction_type_income;

  /// No description provided for @transaction_type_expense.
  ///
  /// In ru, this message translates to:
  /// **'Расход'**
  String get transaction_type_expense;

  /// No description provided for @settings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settings;

  /// No description provided for @theme.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get theme;

  /// No description provided for @theme_light.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get theme_light;

  /// No description provided for @theme_dark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get theme_dark;

  /// No description provided for @theme_system.
  ///
  /// In ru, this message translates to:
  /// **'Системная'**
  String get theme_system;

  /// No description provided for @language.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get language;

  /// No description provided for @currency.
  ///
  /// In ru, this message translates to:
  /// **'Валюта'**
  String get currency;

  /// No description provided for @date_format.
  ///
  /// In ru, this message translates to:
  /// **'Формат даты'**
  String get date_format;

  /// No description provided for @onboarding_title.
  ///
  /// In ru, this message translates to:
  /// **'Добро пожаловать'**
  String get onboarding_title;

  /// No description provided for @onboarding_subtitle.
  ///
  /// In ru, this message translates to:
  /// **'Давайте настроим ваш бизнес'**
  String get onboarding_subtitle;

  /// No description provided for @onboarding_business_name.
  ///
  /// In ru, this message translates to:
  /// **'Название бизнеса'**
  String get onboarding_business_name;

  /// No description provided for @onboarding_owner_name.
  ///
  /// In ru, this message translates to:
  /// **'Ваше имя'**
  String get onboarding_owner_name;

  /// No description provided for @onboarding_business_name_hint.
  ///
  /// In ru, this message translates to:
  /// **'Например: ИП Иванов'**
  String get onboarding_business_name_hint;

  /// No description provided for @onboarding_owner_name_hint.
  ///
  /// In ru, this message translates to:
  /// **'Например: Иван'**
  String get onboarding_owner_name_hint;

  /// No description provided for @onboarding_optional.
  ///
  /// In ru, this message translates to:
  /// **'необязательно'**
  String get onboarding_optional;

  /// No description provided for @onboarding_skip.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить'**
  String get onboarding_skip;

  /// No description provided for @onboarding_continue.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get onboarding_continue;

  /// No description provided for @onboarding_get_started.
  ///
  /// In ru, this message translates to:
  /// **'Начать работу'**
  String get onboarding_get_started;

  /// No description provided for @btn_add.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get btn_add;

  /// No description provided for @btn_save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get btn_save;

  /// No description provided for @btn_cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get btn_cancel;

  /// No description provided for @btn_delete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get btn_delete;

  /// No description provided for @btn_edit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get btn_edit;

  /// No description provided for @btn_confirm.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить'**
  String get btn_confirm;

  /// No description provided for @btn_close.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get btn_close;

  /// No description provided for @btn_view_all.
  ///
  /// In ru, this message translates to:
  /// **'Смотреть все'**
  String get btn_view_all;

  /// No description provided for @btn_retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get btn_retry;

  /// No description provided for @empty_orders.
  ///
  /// In ru, this message translates to:
  /// **'Заказов пока нет'**
  String get empty_orders;

  /// No description provided for @empty_orders_hint.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите + чтобы создать первый заказ'**
  String get empty_orders_hint;

  /// No description provided for @empty_customers.
  ///
  /// In ru, this message translates to:
  /// **'Клиентов пока нет'**
  String get empty_customers;

  /// No description provided for @empty_customers_hint.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите + чтобы добавить клиента'**
  String get empty_customers_hint;

  /// No description provided for @empty_transactions.
  ///
  /// In ru, this message translates to:
  /// **'Транзакций пока нет'**
  String get empty_transactions;

  /// No description provided for @empty_transactions_hint.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите + чтобы добавить транзакцию'**
  String get empty_transactions_hint;

  /// No description provided for @empty_debts.
  ///
  /// In ru, this message translates to:
  /// **'Долгов нет'**
  String get empty_debts;

  /// No description provided for @empty_debts_hint.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите + чтобы добавить долг'**
  String get empty_debts_hint;

  /// No description provided for @confirm_delete_title.
  ///
  /// In ru, this message translates to:
  /// **'Удалить?'**
  String get confirm_delete_title;

  /// No description provided for @confirm_delete_message.
  ///
  /// In ru, this message translates to:
  /// **'Это действие нельзя отменить'**
  String get confirm_delete_message;

  /// No description provided for @confirm_cancel_order.
  ///
  /// In ru, this message translates to:
  /// **'Отменить заказ?'**
  String get confirm_cancel_order;

  /// No description provided for @confirm_cancel_order_message.
  ///
  /// In ru, this message translates to:
  /// **'История платежей будет сохранена'**
  String get confirm_cancel_order_message;

  /// No description provided for @error_required.
  ///
  /// In ru, this message translates to:
  /// **'Обязательное поле'**
  String get error_required;

  /// No description provided for @error_invalid_amount.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректную сумму'**
  String get error_invalid_amount;

  /// No description provided for @error_generic.
  ///
  /// In ru, this message translates to:
  /// **'Что-то пошло не так'**
  String get error_generic;

  /// No description provided for @error_load.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки данных'**
  String get error_load;

  /// No description provided for @search_placeholder.
  ///
  /// In ru, this message translates to:
  /// **'Поиск...'**
  String get search_placeholder;

  /// No description provided for @filter_all.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get filter_all;

  /// No description provided for @filter_active.
  ///
  /// In ru, this message translates to:
  /// **'Активные'**
  String get filter_active;

  /// No description provided for @filter_completed.
  ///
  /// In ru, this message translates to:
  /// **'Завершённые'**
  String get filter_completed;

  /// No description provided for @month_january.
  ///
  /// In ru, this message translates to:
  /// **'Январь'**
  String get month_january;

  /// No description provided for @month_february.
  ///
  /// In ru, this message translates to:
  /// **'Февраль'**
  String get month_february;

  /// No description provided for @month_march.
  ///
  /// In ru, this message translates to:
  /// **'Март'**
  String get month_march;

  /// No description provided for @month_april.
  ///
  /// In ru, this message translates to:
  /// **'Апрель'**
  String get month_april;

  /// No description provided for @month_may.
  ///
  /// In ru, this message translates to:
  /// **'Май'**
  String get month_may;

  /// No description provided for @month_june.
  ///
  /// In ru, this message translates to:
  /// **'Июнь'**
  String get month_june;

  /// No description provided for @month_july.
  ///
  /// In ru, this message translates to:
  /// **'Июль'**
  String get month_july;

  /// No description provided for @month_august.
  ///
  /// In ru, this message translates to:
  /// **'Август'**
  String get month_august;

  /// No description provided for @month_september.
  ///
  /// In ru, this message translates to:
  /// **'Сентябрь'**
  String get month_september;

  /// No description provided for @month_october.
  ///
  /// In ru, this message translates to:
  /// **'Октябрь'**
  String get month_october;

  /// No description provided for @month_november.
  ///
  /// In ru, this message translates to:
  /// **'Ноябрь'**
  String get month_november;

  /// No description provided for @month_december.
  ///
  /// In ru, this message translates to:
  /// **'Декабрь'**
  String get month_december;

  /// No description provided for @profile_business_info.
  ///
  /// In ru, this message translates to:
  /// **'Информация о бизнесе'**
  String get profile_business_info;

  /// No description provided for @profile_management.
  ///
  /// In ru, this message translates to:
  /// **'Управление'**
  String get profile_management;

  /// No description provided for @profile_preferences.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get profile_preferences;

  /// No description provided for @profile_app.
  ///
  /// In ru, this message translates to:
  /// **'Приложение'**
  String get profile_app;

  /// No description provided for @profile_about.
  ///
  /// In ru, this message translates to:
  /// **'О приложении'**
  String get profile_about;

  /// No description provided for @profile_version.
  ///
  /// In ru, this message translates to:
  /// **'Версия'**
  String get profile_version;

  /// No description provided for @recent_activity.
  ///
  /// In ru, this message translates to:
  /// **'Последние операции'**
  String get recent_activity;

  /// No description provided for @active_orders.
  ///
  /// In ru, this message translates to:
  /// **'Активные заказы'**
  String get active_orders;

  /// No description provided for @total_customers.
  ///
  /// In ru, this message translates to:
  /// **'Клиенты'**
  String get total_customers;

  /// No description provided for @monthly_report.
  ///
  /// In ru, this message translates to:
  /// **'Отчёт за месяц'**
  String get monthly_report;

  /// No description provided for @compare_with_prev.
  ///
  /// In ru, this message translates to:
  /// **'Сравнить с прошлым месяцем'**
  String get compare_with_prev;

  /// No description provided for @category_order_payment.
  ///
  /// In ru, this message translates to:
  /// **'Платёж по заказу'**
  String get category_order_payment;

  /// No description provided for @category_service.
  ///
  /// In ru, this message translates to:
  /// **'Услуги'**
  String get category_service;

  /// No description provided for @category_sale.
  ///
  /// In ru, this message translates to:
  /// **'Продажа'**
  String get category_sale;

  /// No description provided for @category_refund_received.
  ///
  /// In ru, this message translates to:
  /// **'Возврат'**
  String get category_refund_received;

  /// No description provided for @category_other_income.
  ///
  /// In ru, this message translates to:
  /// **'Прочий доход'**
  String get category_other_income;

  /// No description provided for @category_supplies.
  ///
  /// In ru, this message translates to:
  /// **'Материалы'**
  String get category_supplies;

  /// No description provided for @category_rent.
  ///
  /// In ru, this message translates to:
  /// **'Аренда'**
  String get category_rent;

  /// No description provided for @category_utilities.
  ///
  /// In ru, this message translates to:
  /// **'Коммунальные'**
  String get category_utilities;

  /// No description provided for @category_transport.
  ///
  /// In ru, this message translates to:
  /// **'Транспорт'**
  String get category_transport;

  /// No description provided for @category_marketing.
  ///
  /// In ru, this message translates to:
  /// **'Маркетинг'**
  String get category_marketing;

  /// No description provided for @category_salary.
  ///
  /// In ru, this message translates to:
  /// **'Зарплата'**
  String get category_salary;

  /// No description provided for @category_equipment.
  ///
  /// In ru, this message translates to:
  /// **'Оборудование'**
  String get category_equipment;

  /// No description provided for @category_other_expense.
  ///
  /// In ru, this message translates to:
  /// **'Прочий расход'**
  String get category_other_expense;

  /// No description provided for @payment_method_cash.
  ///
  /// In ru, this message translates to:
  /// **'Наличные'**
  String get payment_method_cash;

  /// No description provided for @payment_method_card.
  ///
  /// In ru, this message translates to:
  /// **'Карта'**
  String get payment_method_card;

  /// No description provided for @payment_method_transfer.
  ///
  /// In ru, this message translates to:
  /// **'Перевод'**
  String get payment_method_transfer;

  /// No description provided for @payment_method_other.
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get payment_method_other;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
