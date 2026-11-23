import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../providers/customer_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/order_provider.dart';
import '../providers/settings_provider.dart';
import 'api_client.dart';
import 'notification_service.dart';

/// Instant Stale-While-Revalidate loader:
/// 1) Hydrates all providers from local cache in parallel (`Future.wait`) with zero artificial delays.
/// 2) Synchronizes all tabs and dashboard in a single batched `/api/bootstrap` HTTP request.
class BootstrapService {
  BootstrapService._();

  static Future<void>? _inFlight;
  static bool _servicesStarted = false;

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
        // 1. Hydrate all providers from local snapshot cache in parallel immediately.
        await Future.wait([
          dashboard.hydrateFromCache(),
          finance.hydrateFromCache(),
          orders.hydrateFromCache(),
          debts.hydrateFromCache(),
          customers.hydrateFromCache(),
        ]);

        if (!_servicesStarted) {
          _servicesStarted = true;
          ApiClient.instance.startKeepAlive();
          unawaited(NotificationService.instance.init());
        }

        // 2. Single batched network request for user + dashboard + page 1 of all 4 tabs.
        final year = dashboard.year;
        final month = dashboard.month;
        final tz = DateTime.now().timeZoneOffset.inMinutes;

        final raw = await ApiClient.instance.get(
          '/api/bootstrap?year=$year&month=$month&limit=$limit&tz=$tz',
        );

        if (raw is Map) {
          final data = Map<String, dynamic>.from(raw);

          final userJson = data['user'];
          if (userJson is Map) {
            unawaited(
              settings.applyServerUser(Map<String, dynamic>.from(userJson)),
            );
          }

          final dashJson = data['dashboard'];
          if (dashJson is Map) {
            dashboard.applyBootstrapPayload(
              Map<String, dynamic>.from(dashJson),
              year: year,
              month: month,
            );
          }

          final txJson = data['transactions'];
          if (txJson is Map) {
            finance.applyBootstrapPayload(
              Map<String, dynamic>.from(txJson),
              year: year,
              month: month,
            );
          }

          final ordersJson = data['orders'];
          if (ordersJson is Map) {
            orders.applyBootstrapPayload(
              Map<String, dynamic>.from(ordersJson),
            );
          }

          final customersJson = data['customers'];
          if (customersJson is Map) {
            customers.applyBootstrapPayload(
              Map<String, dynamic>.from(customersJson),
            );
          }

          final debtsJson = data['debts'];
          if (debtsJson is Map) {
            debts.applyBootstrapPayload(
              Map<String, dynamic>.from(debtsJson),
            );
          }

          unawaited(
            NotificationService.instance.syncReminders(
              debts: debts.all,
              orders: orders.allOrders,
              locale: settings.locale,
              currency: settings.currency,
            ),
          );
        }
      } catch (_) {
        // Fallback to dashboard load if bootstrap fails
        await dashboard.load();
      } finally {
        _inFlight = null;
      }
    }();

    _inFlight = future;
    return future;
  }
}
