import 'package:flutter/material.dart';
import '../l10n/app_tr.dart';
import '../models/order.dart';
import '../models/debt.dart';
import '../theme/app_colors.dart';

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge._({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  factory AppStatusBadge.order(OrderStatus status, BuildContext context) {
    final colors = context.appColors;
    return switch (status) {
      OrderStatus.newOrder => AppStatusBadge._(
          label: context.tr('Новый', 'New'),
          color: Colors.white,
          backgroundColor: const Color(0xFF0F766E),
        ),
      OrderStatus.inProgress => AppStatusBadge._(
          label: context.tr('В работе', 'In progress'),
          color: Colors.white,
          backgroundColor: const Color(0xFF2563EB),
        ),
      OrderStatus.completed => AppStatusBadge._(
          label: context.tr('Завершён', 'Completed'),
          color: Colors.white,
          backgroundColor: colors.income,
        ),
      OrderStatus.cancelled => AppStatusBadge._(
          label: context.tr('Отменён', 'Cancelled'),
          color: Colors.white,
          backgroundColor: const Color(0xFF64748B),
        ),
    };
  }

  factory AppStatusBadge.debt(DebtStatus status, BuildContext context) {
    final colors = context.appColors;
    return switch (status) {
      DebtStatus.unpaid => AppStatusBadge._(
          label: context.tr('Не оплачен', 'Unpaid'),
          color: Colors.white,
          backgroundColor: const Color(0xFFD97706),
        ),
      DebtStatus.partiallyPaid => AppStatusBadge._(
          label: context.tr('Частично', 'Partial'),
          color: Colors.white,
          backgroundColor: const Color(0xFFEA580C),
        ),
      DebtStatus.paid => AppStatusBadge._(
          label: context.tr('Оплачен', 'Paid'),
          color: Colors.white,
          backgroundColor: colors.income,
        ),
      DebtStatus.overdue => AppStatusBadge._(
          label: context.tr('Просрочен', 'Overdue'),
          color: Colors.white,
          backgroundColor: colors.expense,
        ),
    };
  }

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
