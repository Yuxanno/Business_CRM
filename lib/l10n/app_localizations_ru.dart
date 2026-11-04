// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Бизнес Менеджер';

  @override
  String get appName => 'Business Manager';

  @override
  String get nav_home => 'Главная';

  @override
  String get nav_finance => 'Финансы';

  @override
  String get nav_orders => 'Заказы';

  @override
  String get nav_profile => 'Профиль';

  @override
  String get greeting_morning => 'Доброе утро';

  @override
  String get greeting_day => 'Добрый день';

  @override
  String get greeting_evening => 'Добрый вечер';

  @override
  String get income => 'Доходы';

  @override
  String get expense => 'Расходы';

  @override
  String get profit => 'Прибыль';

  @override
  String get balance => 'Баланс';

  @override
  String get outstanding => 'Долг';

  @override
  String get received => 'Получено';

  @override
  String get remaining => 'Остаток';

  @override
  String get status_new => 'Новый';

  @override
  String get status_in_progress => 'В работе';

  @override
  String get status_completed => 'Завершён';

  @override
  String get status_cancelled => 'Отменён';

  @override
  String get status_unpaid => 'Не оплачен';

  @override
  String get status_partially_paid => 'Частично';

  @override
  String get status_paid => 'Оплачен';

  @override
  String get status_overdue => 'Просрочен';

  @override
  String get orders => 'Заказы';

  @override
  String get order => 'Заказ';

  @override
  String get new_order => 'Новый заказ';

  @override
  String get order_title => 'Название заказа';

  @override
  String get order_price => 'Стоимость';

  @override
  String get order_description => 'Описание';

  @override
  String get order_notes => 'Заметки';

  @override
  String get order_deadline => 'Дедлайн';

  @override
  String get order_customer => 'Клиент';

  @override
  String get order_payments => 'Платежи по заказу';

  @override
  String get record_payment => 'Записать платёж';

  @override
  String get payment_amount => 'Сумма платежа';

  @override
  String get customers => 'Клиенты';

  @override
  String get customer => 'Клиент';

  @override
  String get new_customer => 'Новый клиент';

  @override
  String get customer_name => 'Имя клиента';

  @override
  String get customer_phone => 'Телефон';

  @override
  String get customer_email => 'Email';

  @override
  String get customer_notes => 'Заметки';

  @override
  String get customer_orders => 'Заказы клиента';

  @override
  String get debts => 'Долги';

  @override
  String get debt => 'Долг';

  @override
  String get new_debt => 'Новый долг';

  @override
  String get owed_to_me => 'Мне должны';

  @override
  String get i_owe => 'Я должен';

  @override
  String get debt_person => 'Кому / От кого';

  @override
  String get debt_amount => 'Сумма';

  @override
  String get debt_description => 'Описание';

  @override
  String get debt_due_date => 'Срок';

  @override
  String get transactions => 'Транзакции';

  @override
  String get transaction => 'Транзакция';

  @override
  String get new_transaction => 'Новая транзакция';

  @override
  String get transaction_amount => 'Сумма';

  @override
  String get transaction_category => 'Категория';

  @override
  String get transaction_description => 'Описание';

  @override
  String get transaction_date => 'Дата';

  @override
  String get transaction_type_income => 'Доход';

  @override
  String get transaction_type_expense => 'Расход';

  @override
  String get settings => 'Настройки';

  @override
  String get theme => 'Тема';

  @override
  String get theme_light => 'Светлая';

  @override
  String get theme_dark => 'Тёмная';

  @override
  String get theme_system => 'Системная';

  @override
  String get language => 'Язык';

  @override
  String get currency => 'Валюта';

  @override
  String get date_format => 'Формат даты';

  @override
  String get onboarding_title => 'Добро пожаловать';

  @override
  String get onboarding_subtitle => 'Давайте настроим ваш бизнес';

  @override
  String get onboarding_business_name => 'Название бизнеса';

  @override
  String get onboarding_owner_name => 'Ваше имя';

  @override
  String get onboarding_business_name_hint => 'Например: ИП Иванов';

  @override
  String get onboarding_owner_name_hint => 'Например: Иван';

  @override
  String get onboarding_optional => 'необязательно';

  @override
  String get onboarding_skip => 'Пропустить';

  @override
  String get onboarding_continue => 'Продолжить';

  @override
  String get onboarding_get_started => 'Начать работу';

  @override
  String get btn_add => 'Добавить';

  @override
  String get btn_save => 'Сохранить';

  @override
  String get btn_cancel => 'Отмена';

  @override
  String get btn_delete => 'Удалить';

  @override
  String get btn_edit => 'Редактировать';

  @override
  String get btn_confirm => 'Подтвердить';

  @override
  String get btn_close => 'Закрыть';

  @override
  String get btn_view_all => 'Смотреть все';

  @override
  String get btn_retry => 'Повторить';

  @override
  String get empty_orders => 'Заказов пока нет';

  @override
  String get empty_orders_hint => 'Нажмите + чтобы создать первый заказ';

  @override
  String get empty_customers => 'Клиентов пока нет';

  @override
  String get empty_customers_hint => 'Нажмите + чтобы добавить клиента';

  @override
  String get empty_transactions => 'Транзакций пока нет';

  @override
  String get empty_transactions_hint => 'Нажмите + чтобы добавить транзакцию';

  @override
  String get empty_debts => 'Долгов нет';

  @override
  String get empty_debts_hint => 'Нажмите + чтобы добавить долг';

  @override
  String get confirm_delete_title => 'Удалить?';

  @override
  String get confirm_delete_message => 'Это действие нельзя отменить';

  @override
  String get confirm_cancel_order => 'Отменить заказ?';

  @override
  String get confirm_cancel_order_message => 'История платежей будет сохранена';

  @override
  String get error_required => 'Обязательное поле';

  @override
  String get error_invalid_amount => 'Введите корректную сумму';

  @override
  String get error_generic => 'Что-то пошло не так';

  @override
  String get error_load => 'Ошибка загрузки данных';

  @override
  String get search_placeholder => 'Поиск...';

  @override
  String get filter_all => 'Все';

  @override
  String get filter_active => 'Активные';

  @override
  String get filter_completed => 'Завершённые';

  @override
  String get month_january => 'Январь';

  @override
  String get month_february => 'Февраль';

  @override
  String get month_march => 'Март';

  @override
  String get month_april => 'Апрель';

  @override
  String get month_may => 'Май';

  @override
  String get month_june => 'Июнь';

  @override
  String get month_july => 'Июль';

  @override
  String get month_august => 'Август';

  @override
  String get month_september => 'Сентябрь';

  @override
  String get month_october => 'Октябрь';

  @override
  String get month_november => 'Ноябрь';

  @override
  String get month_december => 'Декабрь';

  @override
  String get profile_business_info => 'Информация о бизнесе';

  @override
  String get profile_management => 'Управление';

  @override
  String get profile_preferences => 'Настройки';

  @override
  String get profile_app => 'Приложение';

  @override
  String get profile_about => 'О приложении';

  @override
  String get profile_version => 'Версия';

  @override
  String get recent_activity => 'Последние операции';

  @override
  String get active_orders => 'Активные заказы';

  @override
  String get total_customers => 'Клиенты';

  @override
  String get monthly_report => 'Отчёт за месяц';

  @override
  String get compare_with_prev => 'Сравнить с прошлым месяцем';

  @override
  String get category_order_payment => 'Платёж по заказу';

  @override
  String get category_service => 'Услуги';

  @override
  String get category_sale => 'Продажа';

  @override
  String get category_refund_received => 'Возврат';

  @override
  String get category_other_income => 'Прочий доход';

  @override
  String get category_supplies => 'Материалы';

  @override
  String get category_rent => 'Аренда';

  @override
  String get category_utilities => 'Коммунальные';

  @override
  String get category_transport => 'Транспорт';

  @override
  String get category_marketing => 'Маркетинг';

  @override
  String get category_salary => 'Зарплата';

  @override
  String get category_equipment => 'Оборудование';

  @override
  String get category_other_expense => 'Прочий расход';

  @override
  String get payment_method_cash => 'Наличные';

  @override
  String get payment_method_card => 'Карта';

  @override
  String get payment_method_transfer => 'Перевод';

  @override
  String get payment_method_other => 'Другое';
}
