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

/// Fetches the entire initial app state (user profile, dashboard, transactions,
/// orders, customers, and debts + counts) in ONE batched HTTP request.
class BootstrapService {
  BootstrapService._();

  static Future<void>? _inFlight;

  static Future<void> loadAll(BuildContext context, {int limit = 30}) {
    if (_inFlight != null) return _inFlight!;

    final settings = context.read<SettingsProvider>();
    final dashboard = context.read<DashboardProvider>();
    final finance = context.read<FinanceProvider>();
    final orders = context.read<OrderProvider>();
    final customers = context.read<CustomerProvider>();
    final debts = context.read<DebtProvider>();

    final year = dashboard.year;
    final month = dashboard.month;
    final tz = DateTime.now().timeZoneOffset.inMinutes;

    final future = () async {
      try {
        final raw = await ApiClient.instance.get(
          '/api/bootstrap?year=$year&month=$month&tz=$tz&limit=$limit',
        );
        if (raw is! Map) return;
        final data = Map<String, dynamic>.from(raw);

        if (data['user'] is Map) {
          await settings.applyServerUser(
            Map<String, dynamic>.from(data['user'] as Map),
          );
        }
        if (data['dashboard'] is Map) {
          dashboard.applyBootstrapPayload(
            Map<String, dynamic>.from(data['dashboard'] as Map),
            year: year,
            month: month,
          );
        }
        if (data['transactions'] is Map) {
          finance.applyBootstrapPayload(
            Map<String, dynamic>.from(data['transactions'] as Map),
            year: year,
            month: month,
          );
        }
        if (data['orders'] is Map) {
          orders.applyBootstrapPayload(
            Map<String, dynamic>.from(data['orders'] as Map),
          );
        }
        if (data['customers'] is Map) {
          customers.applyBootstrapPayload(
            Map<String, dynamic>.from(data['customers'] as Map),
          );
        }
        if (data['debts'] is Map) {
          debts.applyBootstrapPayload(
            Map<String, dynamic>.from(data['debts'] as Map),
          );
        }
        NotificationService.instance.syncReminders(
          debts: debts.all,
          orders: orders.allOrders,
          locale: settings.locale,
          currency: settings.currency,
        );
      } catch (_) {
        // Fallback to single dashboard fetch if bootstrap endpoint is unavailable
        await dashboard.load();
      } finally {
        _inFlight = null;
      }
    }();

    _inFlight = future;
    return future;
  }
}

