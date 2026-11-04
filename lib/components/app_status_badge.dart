import 'package:flutter/material.dart';
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
          label: 'Новый',
          color: AppColors.primary,
          backgroundColor: colors.primaryContainer,
        ),
      OrderStatus.inProgress => AppStatusBadge._(
          label: 'В работе',
          color: const Color(0xFF3B82F6),
          backgroundColor: const Color(0xFFEFF6FF),
        ),
      OrderStatus.completed => AppStatusBadge._(
          label: 'Завершён',
          color: colors.income,
          backgroundColor: colors.incomeBackground,
        ),
      OrderStatus.cancelled => AppStatusBadge._(
          label: 'Отменён',
          color: colors.textMuted,
          backgroundColor: colors.surfaceSecondary,
        ),
    };
  }

  factory AppStatusBadge.debt(DebtStatus status, BuildContext context) {
    final colors = context.appColors;
    return switch (status) {
      DebtStatus.unpaid => AppStatusBadge._(
          label: 'Не оплачен',
          color: colors.warning,
          backgroundColor: colors.warningBackground,
        ),
      DebtStatus.partiallyPaid => AppStatusBadge._(
          label: 'Частично',
          color: const Color(0xFFF97316),
          backgroundColor: const Color(0xFFFFF7ED),
        ),
      DebtStatus.paid => AppStatusBadge._(
          label: 'Оплачен',
          color: colors.income,
          backgroundColor: colors.incomeBackground,
        ),
      DebtStatus.overdue => AppStatusBadge._(
          label: 'Просрочен',
          color: colors.expense,
          backgroundColor: colors.expenseBackground,
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
