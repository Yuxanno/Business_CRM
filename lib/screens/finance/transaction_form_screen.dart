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
import '../../components/app_button.dart';

class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({
    super.key,
    this.transactionId,
    this.initialType,
  });

  final String? transactionId;

  /// Pre-select type when launched from FAB quick actions.
  final TransactionType? initialType;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
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

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _type = widget.initialType!;
    }
    if (widget.transactionId != null) {
      _isEdit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final provider = context.read<FinanceProvider>();
        // Find in current list
        final found = provider.transactions
            .where((t) => t.id == widget.transactionId)
            .firstOrNull;
        if (found != null && mounted) {
          _existing = found;
          _type = found.type;
          _amountCtrl.text =
              (found.amountCents / 100).toStringAsFixed(2);
          _descCtrl.text = found.description ?? '';
          _notesCtrl.text = found.notes ?? '';
          _category = found.category;
          _date = found.date;
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cents = FinancialCalculator.parseAmountToCents(_amountCtrl.text);
    if (cents == null || cents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректную сумму')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      if (_isEdit && _existing != null) {
        final updated = _existing!.copyWith(
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
        );
        await context.read<FinanceProvider>().update(updated);
      } else {
        const uuid = Uuid();
        final tx = AppTransaction(
          id: uuid.v4(),
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
        );
        await context.read<FinanceProvider>().add(tx);
      }
      HapticFeedback.mediumImpact();
      if (mounted) context.go('/finance');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currency = context.watch<SettingsProvider>().currency;

    final categories = _type == TransactionType.income
        ? TransactionCategories.income
        : TransactionCategories.expense;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Редактировать' : 'Новая операция'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            // Type selector
            _label(context, 'Тип операции'),
            const SizedBox(height: AppSpacing.sm),
            _TypeSelector(
              value: _type,
              onChanged: (v) {
                setState(() {
                  _type = v;
                  _category = null;
                });
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'Сумма ($currency) *'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              style: TextStyle(color: colors.textPrimary),
              autofocus: !_isEdit,
              decoration: const InputDecoration(hintText: '0.00'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Обязательное поле';
                final c = FinancialCalculator.parseAmountToCents(v);
                if (c == null || c <= 0) return 'Введите корректную сумму';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'Категория'),
            const SizedBox(height: AppSpacing.sm),
            _CategorySelector(
              categories: categories,
              selected: _category,
              type: _type,
              onChanged: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'Описание'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _descCtrl,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: _type == TransactionType.income
                    ? 'Откуда доход...'
                    : 'На что потрачено...',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'Дата'),
            const SizedBox(height: AppSpacing.xs),
            _DatePicker(
              value: _date,
              onChanged: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'Заметки'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              style: TextStyle(color: colors.textPrimary),
              decoration:
                  const InputDecoration(hintText: 'Дополнительная информация...'),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            AppButton(
              label: _isEdit ? 'Сохранить' : 'Добавить операцию',
              onPressed: _save,
              isLoading: _loading,
              icon: Icons.check_rounded,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    final colors = context.appColors;
    return Text(text,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary));
  }
}

// ─── Type Selector ────────────────────────────────────────────────────────────

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.value, required this.onChanged});
  final TransactionType value;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        Expanded(
          child: _TypeOption(
            label: 'Доход',
            icon: Icons.trending_up_rounded,
            selected: value == TransactionType.income,
            selectedColor: colors.income,
            onTap: () => onChanged(TransactionType.income),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _TypeOption(
            label: 'Расход',
            icon: Icons.trending_down_rounded,
            selected: value == TransactionType.expense,
            selectedColor: colors.expense,
            onTap: () => onChanged(TransactionType.expense),
          ),
        ),
      ],
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 60,
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withOpacity(0.12)
              : colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? selectedColor : colors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 20,
                color: selected ? selectedColor : colors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? selectedColor : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Category Selector ────────────────────────────────────────────────────────

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.categories,
    required this.selected,
    required this.type,
    required this.onChanged,
  });

  final List<String> categories;
  final String? selected;
  final TransactionType type;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: categories.map((cat) {
        final isSelected = selected == cat;
        final label = _labelFor(cat);
        return GestureDetector(
          onTap: () => onChanged(isSelected ? null : cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? (type == TransactionType.income
                      ? colors.incomeBackground
                      : colors.expenseBackground)
                  : colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(
                color: isSelected
                    ? (type == TransactionType.income
                        ? colors.income
                        : colors.expense)
                    : colors.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? (type == TransactionType.income
                        ? colors.income
                        : colors.expense)
                    : colors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _labelFor(String cat) {
    const labels = {
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
    return labels[cat] ?? cat;
  }
}

// ─── Date Picker ──────────────────────────────────────────────────────────────

class _DatePicker extends StatelessWidget {
  const _DatePicker({required this.value, required this.onChanged});
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(ctx)
                  .colorScheme
                  .copyWith(primary: colors.primary),
            ),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 16, color: colors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}',
              style: TextStyle(fontSize: 14, color: colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
