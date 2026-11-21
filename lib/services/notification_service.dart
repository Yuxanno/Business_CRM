import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_tr.dart';
import '../models/debt.dart';
import '../models/order.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import 'financial_calculator.dart';
import 'notification_platform.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _askedKey = 'notif_permission_asked';
  static const _enabledKey = 'notif_enabled';

  bool _initialized = false;
  bool _enabled = false;
  bool _promptVisible = false;

  List<Debt> _lastDebts = const [];
  List<Order> _lastOrders = const [];
  String _lastLocale = 'ru';
  String _lastCurrency = 'UZS';
  bool _hasSnapshot = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await initPlatformNotifications();
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? false;
    } catch (_) {}
  }

  /// Asks the user for notification permission once after fresh install.
  Future<void> promptPermissionIfNeeded(BuildContext context) async {
    if (_promptVisible) return;
    await init();
    final prefs = await SharedPreferences.getInstance();
    final asked = prefs.getBool(_askedKey) ?? false;
    if (asked || !context.mounted) return;

    _promptVisible = true;
    final colors = context.appColors;
    final locale = context.read<SettingsProvider>().locale;
    final isEn = locale == 'en';

    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.border),
        ),
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.notifications_active_outlined,
            size: 26,
            color: colors.primary,
          ),
        ),
        title: Text(
          isEn ? 'Enable payment reminders?' : 'Включить напоминания об оплате?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          isEn
              ? 'BizFlow will notify you if a debt or order payment is due tomorrow, today, or overdue.'
              : 'BizFlow напомнит, если завтра или сегодня нужно оплатить долг, получить оплату или если платёж просрочен.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: colors.textSecondary,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    isEn ? 'Later' : 'Позже',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    isEn ? 'Allow' : 'Разрешить',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    _promptVisible = false;
    await prefs.setBool(_askedKey, true);

    if (allow == true) {
      final granted = await requestPlatformNotificationPermission();
      _enabled = granted;
      await prefs.setBool(_enabledKey, granted);
      if (granted && _hasSnapshot) {
        await _syncInternal();
      }
    } else {
      _enabled = false;
      await prefs.setBool(_enabledKey, false);
    }
  }

  /// Updates the reminder snapshot and reschedules/triggers notifications in [locale].
  Future<void> syncReminders({
    required List<Debt> debts,
    required List<Order> orders,
    required String locale,
    required String currency,
  }) async {
    _lastDebts = List<Debt>.from(debts);
    _lastOrders = List<Order>.from(orders);
    _lastLocale = locale;
    _lastCurrency = currency;
    _hasSnapshot = true;

    await _syncInternal();
  }

  /// Updates only the debt list and reschedules reminders if a snapshot exists.
  Future<void> updateDebts(List<Debt> debts) async {
    _lastDebts = List<Debt>.from(debts);
    if (_hasSnapshot) {
      await _syncInternal();
    }
  }

  /// Updates only the order list and reschedules reminders if a snapshot exists.
  Future<void> updateOrders(List<Order> orders) async {
    _lastOrders = List<Order>.from(orders);
    if (_hasSnapshot) {
      await _syncInternal();
    }
  }

  /// Rebuilds scheduled notifications immediately when the user switches app language.
  Future<void> onLocaleChanged(String locale) async {
    _lastLocale = locale;
    if (_hasSnapshot) {
      await _syncInternal();
    }
  }

  Future<void> _syncInternal() async {
    await init();
    await cancelAllPlatformNotifications();
    if (!_enabled) return;

    final isEn = _lastLocale == 'en';
    final currency = _lastCurrency;
    final prefs = await SharedPreferences.getInstance();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    var nextScheduleId = 1000;

    String formatAmount(int cents) {
      final prev = AppTr.isEn;
      AppTr.isEn = isEn;
      final out = FinancialCalculator.formatCents(cents, currency: currency);
      AppTr.isEn = prev;
      return out;
    }

    String formatShort(DateTime dt) {
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      return '$d.$m.${dt.year}';
    }

    Future<void> notifyOnceToday({
      required String uniqueKey,
      required String title,
      required String body,
    }) async {
      final shownKey = 'notif_shown_${todayKey}_$uniqueKey';
      if (prefs.getBool(shownKey) == true) return;
      await prefs.setBool(shownKey, true);
      await showPlatformNotification(
        id: nextScheduleId++,
        title: title,
        body: body,
      );
    }

    // 1. Standalone debts (both "I owe" and "Owed to me")
    for (final debt in _lastDebts) {
      if (debt.isFullyPaid || debt.dueDate == null) continue;
      final due = debt.dueDate!;
      final dueDay = DateTime(due.year, due.month, due.day);
      final amount = formatAmount(debt.remainingCents);
      final isPayable = debt.direction == DebtDirection.payable;

      if (dueDay.isBefore(today)) {
        final title = isEn
            ? (isPayable
                ? 'Overdue debt: ${debt.personName}'
                : 'Overdue payment: ${debt.personName}')
            : (isPayable
                ? 'Просрочен ваш долг: ${debt.personName}'
                : 'Просрочена оплата: ${debt.personName}');
        final body = isEn
            ? (isPayable
                ? 'You owe $amount (due ${formatShort(due)})'
                : 'Owed to you: $amount (due ${formatShort(due)})')
            : (isPayable
                ? 'Нужно оплатить $amount (срок был ${formatShort(due)})'
                : 'Вам должны вернуть $amount (срок был ${formatShort(due)})');
        await notifyOnceToday(
          uniqueKey: 'debt_overdue_${debt.id}',
          title: title,
          body: body,
        );
      } else if (dueDay.isAtSameMomentAs(today)) {
        final title = isEn
            ? (isPayable
                ? 'Debt due today: ${debt.personName}'
                : 'Payment expected today: ${debt.personName}')
            : (isPayable
                ? 'Сегодня нужно оплатить долг: ${debt.personName}'
                : 'Сегодня должны вернуть долг: ${debt.personName}');
        final body = isEn
            ? (isPayable
                ? 'Amount to pay today: $amount'
                : 'Amount owed to you today: $amount')
            : (isPayable
                ? 'Сумма к оплате сегодня: $amount'
                : 'Ожидается возврат: $amount');
        await notifyOnceToday(
          uniqueKey: 'debt_today_${debt.id}',
          title: title,
          body: body,
        );
      } else if (dueDay.isAtSameMomentAs(tomorrow)) {
        final title = isEn
            ? (isPayable
                ? 'Debt due tomorrow: ${debt.personName}'
                : 'Payment expected tomorrow: ${debt.personName}')
            : (isPayable
                ? 'Завтра нужно оплатить долг: ${debt.personName}'
                : 'Завтра должны вернуть долг: ${debt.personName}');
        final body = isEn
            ? (isPayable
                ? 'Tomorrow you need to pay $amount'
                : 'Tomorrow $amount is owed to you')
            : (isPayable
                ? 'Завтра срок оплаты: $amount'
                : 'Завтра вам должны заплатить $amount');
        await notifyOnceToday(
          uniqueKey: 'debt_tomorrow_${debt.id}',
          title: title,
          body: body,
        );

        if (!kIsWeb) {
          await schedulePlatformNotification(
            id: nextScheduleId++,
            title: isEn
                ? (isPayable
                    ? 'Debt due today: ${debt.personName}'
                    : 'Payment expected today: ${debt.personName}')
                : (isPayable
                    ? 'Сегодня нужно оплатить долг: ${debt.personName}'
                    : 'Сегодня должны вернуть долг: ${debt.personName}'),
            body: isEn
                ? (isPayable
                    ? 'Amount to pay today: $amount'
                    : 'Amount owed to you today: $amount')
                : (isPayable
                    ? 'Сумма к оплате сегодня: $amount'
                    : 'Ожидается возврат: $amount'),
            localScheduledAt:
                DateTime(dueDay.year, dueDay.month, dueDay.day, 9, 0),
          );
        }
      } else if (!kIsWeb) {
        // Schedule 1 day before and on the due day at 09:00
        final dayBefore = dueDay.subtract(const Duration(days: 1));
        await schedulePlatformNotification(
          id: nextScheduleId++,
          title: isEn
              ? (isPayable
                  ? 'Debt due tomorrow: ${debt.personName}'
                  : 'Payment expected tomorrow: ${debt.personName}')
              : (isPayable
                  ? 'Завтра нужно оплатить долг: ${debt.personName}'
                  : 'Завтра должны вернуть долг: ${debt.personName}'),
          body: isEn
              ? (isPayable
                  ? 'Tomorrow you need to pay $amount'
                  : 'Tomorrow $amount is owed to you')
              : (isPayable
                  ? 'Завтра срок оплаты: $amount'
                  : 'Завтра вам должны заплатить $amount'),
          localScheduledAt:
              DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 9, 0),
        );
        await schedulePlatformNotification(
          id: nextScheduleId++,
          title: isEn
              ? (isPayable
                  ? 'Debt due today: ${debt.personName}'
                  : 'Payment expected today: ${debt.personName}')
              : (isPayable
                  ? 'Сегодня нужно оплатить долг: ${debt.personName}'
                  : 'Сегодня должны вернуть долг: ${debt.personName}'),
          body: isEn
              ? (isPayable
                  ? 'Amount to pay today: $amount'
                  : 'Amount owed to you today: $amount')
              : (isPayable
                  ? 'Сумма к оплате сегодня: $amount'
                  : 'Ожидается возврат: $amount'),
          localScheduledAt:
              DateTime(dueDay.year, dueDay.month, dueDay.day, 9, 0),
        );
      }
    }

    // 2. Unpaid orders with due dates
    for (final order in _lastOrders) {
      if (order.status == OrderStatus.cancelled ||
          order.isFullyPaid ||
          order.dueDate == null) {
        continue;
      }
      final due = order.dueDate!;
      final dueDay = DateTime(due.year, due.month, due.day);
      final amount = formatAmount(order.remainingCents);

      if (dueDay.isBefore(today)) {
        await notifyOnceToday(
          uniqueKey: 'order_overdue_${order.id}',
          title: isEn
              ? 'Overdue order payment: ${order.customerName}'
              : 'Просрочена оплата заказа: ${order.customerName}',
          body: isEn
              ? '${order.title} — $amount (due ${formatShort(due)})'
              : '«${order.title}» — $amount (срок был ${formatShort(due)})',
        );
      } else if (dueDay.isAtSameMomentAs(today)) {
        await notifyOnceToday(
          uniqueKey: 'order_today_${order.id}',
          title: isEn
              ? 'Order payment due today: ${order.customerName}'
              : 'Сегодня оплата по заказу: ${order.customerName}',
          body: isEn
              ? '${order.title} — expected today: $amount'
              : '«${order.title}» — к оплате сегодня: $amount',
        );
      } else if (dueDay.isAtSameMomentAs(tomorrow)) {
        await notifyOnceToday(
          uniqueKey: 'order_tomorrow_${order.id}',
          title: isEn
              ? 'Order payment due tomorrow: ${order.customerName}'
              : 'Завтра оплата по заказу: ${order.customerName}',
          body: isEn
              ? '${order.title} — expected tomorrow: $amount'
              : '«${order.title}» — завтра должны оплатить $amount',
        );

        if (!kIsWeb) {
          await schedulePlatformNotification(
            id: nextScheduleId++,
            title: isEn
                ? 'Order payment due today: ${order.customerName}'
                : 'Сегодня оплата по заказу: ${order.customerName}',
            body: isEn
                ? '${order.title} — expected today: $amount'
                : '«${order.title}» — к оплате сегодня: $amount',
            localScheduledAt:
                DateTime(dueDay.year, dueDay.month, dueDay.day, 9, 0),
          );
        }
      } else if (!kIsWeb) {
        final dayBefore = dueDay.subtract(const Duration(days: 1));
        await schedulePlatformNotification(
          id: nextScheduleId++,
          title: isEn
              ? 'Order payment due tomorrow: ${order.customerName}'
              : 'Завтра оплата по заказу: ${order.customerName}',
          body: isEn
              ? '${order.title} — expected tomorrow: $amount'
              : '«${order.title}» — завтра должны оплатить $amount',
          localScheduledAt:
              DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 9, 0),
        );
        await schedulePlatformNotification(
          id: nextScheduleId++,
          title: isEn
              ? 'Order payment due today: ${order.customerName}'
              : 'Сегодня оплата по заказу: ${order.customerName}',
          body: isEn
              ? '${order.title} — expected today: $amount'
              : '«${order.title}» — к оплате сегодня: $amount',
          localScheduledAt:
              DateTime(dueDay.year, dueDay.month, dueDay.day, 9, 0),
        );
      }
    }
  }
}
