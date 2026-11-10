import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/transaction.dart';
import '../../providers/finance_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../components/app_modal_sheet.dart';
import '../../components/form_widgets.dart';

// ─── Route wrapper ────────────────────────────────────────────────────────────

class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({
    super.key,
    this.transactionId,
    this.initialType,
  });

  final String? transactionId;
  final TransactionType? initialType;

  @override
  State<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    await showAppModal<void>(
      context: context,
      child: _TransactionFormSheet(
        transactionId: widget.transactionId,
        initialType: widget.initialType,
      ),
    );
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/finance');
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: Colors.transparent);
}

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _TransactionFormSheet extends StatefulWidget {
  const _TransactionFormSheet({this.transactionId, this.initialType});
  final String? transactionId;
  final TransactionType? initialType;

  @override
  State<_TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<_TransactionFormSheet>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  TransactionType _type = TransactionType.income;
  String? _category;
  DateTime _date = DateTime.now();
  bool _loading = false;
  bool _isEdit = false;
  AppTransaction? _existing;

  late AnimationController _stagger;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _stagger.forward();

    if (widget.initialType != null) _type = widget.initialType!;

    if (widget.transactionId != null) {
      _isEdit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final found = context
            .read<FinanceProvider>()
            .transactions
            .where((t) => t.id == widget.transactionId)
            .firstOrNull;
        if (found != null && mounted) {
          setState(() {
            _existing = found;
            _type = found.type;
            _amountCtrl.text =
                (found.amountCents / 100).toStringAsFixed(2);
            _descCtrl.text = found.description ?? '';
            _notesCtrl.text = found.notes ?? '';
            _category = found.category;
            _date = found.date;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _stagger.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cents = FinancialCalculator.parseAmountToCents(_amountCtrl.text);
    if (cents == null || cents <= 0) return;

    setState(() => _loading = true);
    try {
      if (_isEdit && _existing != null) {
        await context.read<FinanceProvider>().update(
              _existing!.copyWith(
                amountCents: cents,
                type: _type,
                category: _category,
                description: _descCtrl.text.trim().isNotEmpty
                    ? _descCtrl.text.trim()
                    : null,
                notes: _notesCtrl.text.trim().isNotEmpty
                    ? _notesCtrl.text.trim()
                    : null,
                date: _date,
              ),
            );
      } else {
        await context.read<FinanceProvider>().add(
              AppTransaction(
                id: const Uuid().v4(),
                amountCents: cents,
                type: _type,
                category: _category,
                description: _descCtrl.text.trim().isNotEmpty
                    ? _descCtrl.text.trim()
                    : null,
                notes: _notesCtrl.text.trim().isNotEmpty
                    ? _notesCtrl.text.trim()
                    : null,
                date: _date,
                createdAt: DateTime.now(),
                linkedEntityType: 'manual',
              ),
            );
      }
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currency = context.watch<SettingsProvider>().currency;
    final isIncome = _type == TransactionType.income;
    final accent = isIncome ? colors.income : colors.expense;

    return AppModalSheet(
      title: _isEdit
          ? 'Изменить операцию'
          : (isIncome ? 'Новый доход' : 'Новый расход'),
      subtitle: _isEdit
          ? 'Сумма и дата обновят итог месяца'
          : (isIncome
              ? 'Эта сумма прибавится к доходам выбранного месяца'
              : 'Эта сумма прибавится к расходам выбранного месяца'),
      headerIcon:
          isIncome ? Icons.trending_up_rounded : Icons.trending_down_rounded,
      headerColor: accent,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl + MediaQuery.of(context).viewInsets.bottom,
          ),
          shrinkWrap: true,
          children: [
            // Type toggle
            FormStaggerItem(
              animation: _stagger,
              index: 0,
              child: _TypeToggle(
                value: _type,
                onChanged: (v) => setState(() {
                  _type = v;
                  _category = null;
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Amount
            FormStaggerItem(
              animation: _stagger,
              index: 1,
              child: SheetField(
                label: 'СУММА ($currency)',
                required: true,
                child: FormAmountField(
                  controller: _amountCtrl,
                  accentColor: accent,
                  prefix: isIncome ? '+' : '−',
                  autofocus: !_isEdit,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Category
            FormStaggerItem(
              animation: _stagger,
              index: 2,
              child: SheetField(
                label: 'КАТЕГОРИЯ',
                child: _CategoryChips(
                  categories: isIncome
                      ? TransactionCategories.income
                      : TransactionCategories.expense,
                  selected: _category,
                  accentColor: accent,
                  onChanged: (c) => setState(() => _category = c),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Description
            FormStaggerItem(
              animation: _stagger,
              index: 3,
              child: SheetField(
                label: 'ОПИСАНИЕ',
                child: FormTextField(
                  controller: _descCtrl,
                  hint: isIncome ? 'Откуда доход...' : 'На что потрачено...',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Date
            FormStaggerItem(
              animation: _stagger,
              index: 4,
              child: SheetField(
                label: 'ДАТА',
                child: FormDatePicker(
                  value: _date,
                  onChanged: (d) => setState(() => _date = d ?? _date),
                  accentColor: accent,
                  allowPast: true,
                  nullable: false,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Notes
            FormStaggerItem(
              animation: _stagger,
              index: 5,
              child: SheetField(
                label: 'ЗАМЕТКИ',
                child: FormTextField(
                  controller: _notesCtrl,
                  hint: 'Дополнительная информация...',
                  maxLines: 2,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            FormStaggerItem(
              animation: _stagger,
              index: 6,
              child: FormSubmitButton(
                label: _isEdit ? 'Сохранить изменения' : 'Добавить операцию',
                accentColor: accent,
                isLoading: _loading,
                onPressed: _save,
                icon: _isEdit ? Icons.check_rounded : Icons.add_rounded,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

// ─── Type toggle ──────────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.value, required this.onChanged});
  final TransactionType value;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isIncome = value == TransactionType.income;

    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment:
                isIncome ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: isIncome ? colors.income : colors.expense,
                  borderRadius: BorderRadius.circular(AppRadius.md - 2),
                  boxShadow: [
                    BoxShadow(
                      color: (isIncome ? colors.income : colors.expense)
                          .withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              _ToggleLabel(
                label: 'Доход',
                icon: Icons.trending_up_rounded,
                active: isIncome,
                onTap: () => onChanged(TransactionType.income),
              ),
              _ToggleLabel(
                label: 'Расход',
                icon: Icons.trending_down_rounded,
                active: !isIncome,
                onTap: () => onChanged(TransactionType.expense),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleLabel extends StatelessWidget {
  const _ToggleLabel({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? Colors.white : colors.textSecondary,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 16,
                    color: active ? Colors.white : colors.textMuted),
                const SizedBox(width: 6),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Category chips ───────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.accentColor,
    required this.onChanged,
  });

  final List<String> categories;
  final String? selected;
  final Color accentColor;
  final ValueChanged<String?> onChanged;

  static const _labels = {
    'order_payment': 'Оплата заказа',
    'service': 'Услуга',
    'sale': 'Продажа',
    'refund_received': 'Возврат',
    'other_income': 'Прочее',
    'supplies': 'Материалы',
    'rent': 'Аренда',
    'utilities': 'Коммуналка',
    'transport': 'Транспорт',
    'marketing': 'Маркетинг',
    'salary': 'Зарплата',
    'equipment': 'Оборудование',
    'other_expense': 'Прочее',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: categories.map((cat) {
        final isSelected = selected == cat;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(isSelected ? null : cat);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.12)
                  : colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(
                color: isSelected ? accentColor : colors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Icon(Icons.check_rounded, size: 11, color: accentColor),
                  const SizedBox(width: 3),
                ],
                Text(
                  _labels[cat] ?? cat,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? accentColor : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// FormStaggerItem is used directly from form_widgets.dart
