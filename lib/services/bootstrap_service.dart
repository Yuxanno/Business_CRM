import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../providers/customer_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/order_provider.dart';
import '../providers/settings_provider.dart';
import 'notification_service.dart';

/// Priority-first loader:
/// 1) Immediately loads ONLY what is currently visible on HomeScreen (`/api/dashboard`).
/// 2) Gently warms up secondary tabs one-by-one in the background with short pauses
///    so neither the backend nor the device UI thread is ever overloaded.
class BootstrapService {
  BootstrapService._();

  static Future<void>? _inFlight;
  static bool _warmupRunning = false;

  static Future<void> loadAll(BuildContext context, {int limit = 20}) {
    if (_inFlight != null) return _inFlight!;

    final settings = context.read<SettingsProvider>();
    final dashboard = context.read<DashboardProvider>();
    final finance = context.read<FinanceProvider>();
    final orders = context.read<OrderProvider>();
    final customers = context.read<CustomerProvider>();
    final debts = context.read<DebtProvider>();

    final future = () async {
      try {
        // Phase 1 (Priority 1): Load ONLY the currently visible Home dashboard first.
        await dashboard.load();
      } catch (_) {
      } finally {
        _inFlight = null;
      }

      // Phase 2 (Priority 2): Gentle staggered background warmup for other tabs.
      if (!_warmupRunning) {
        _warmupRunning = true;
        unawaited(() async {
          try {
            await Future<void>.delayed(const Duration(milliseconds: 450));
            await finance.prefetchIfNeeded();

            await Future<void>.delayed(const Duration(milliseconds: 550));
            await orders.prefetchIfNeeded();

            await Future<void>.delayed(const Duration(milliseconds: 550));
            await debts.prefetchIfNeeded();

            await Future<void>.delayed(const Duration(milliseconds: 550));
            await customers.prefetchIfNeeded();

            await NotificationService.instance.syncReminders(
              debts: debts.all,
              orders: orders.allOrders,
              locale: settings.locale,
              currency: settings.currency,
            );
          } catch (_) {
          } finally {
            _warmupRunning = false;
          }
        }());
      }
    }();

    _inFlight = future;
    return future;
  }
}
