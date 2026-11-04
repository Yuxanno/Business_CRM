import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/debt.dart';
import '../../providers/debt_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../components/app_button.dart';

class DebtFormScreen extends StatefulWidget {
  const DebtFormScreen({super.key, this.debtId});
  final String? debtId;

  @override
  State<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends State<DebtFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DebtDirection _direction = DebtDirection.receivable;
  DateTime? _dueDate;
  bool _loading = false;
  bool _isEdit = false;
  Debt? _existing;

  @override
  void initState() {
    super.initState();
    if (widget.debtId != null) {
      _isEdit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final debt =
            await context.read<DebtProvider>().getById(widget.debtId!);
        if (debt != null && mounted) {
          _existing = debt;
          _nameCtrl.text = debt.personName;
          _amountCtrl.text =
              (debt.originalAmountCents / 100).toStringAsFixed(2);
          _descCtrl.text = debt.description ?? '';
          _notesCtrl.text = debt.notes ?? '';
          _direction = debt.direction;
          _dueDate = debt.dueDate;
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amountCents =
        FinancialCalculator.parseAmountToCents(_amountCtrl.text);
    if (amountCents == null || amountCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректную сумму')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      if (_isEdit && _existing != null) {
        final updated = _existing!.copyWith(
          personName: _nameCtrl.text.trim(),
          direction: _direction,
          originalAmountCents: amountCents,
          description: _descCtrl.text.trim().isNotEmpty
              ? _descCtrl.text.trim()
              : null,
          notes: _notesCtrl.text.trim().isNotEmpty
              ? _notesCtrl.text.trim()
              : null,
          dueDate: _dueDate,
          updatedAt: DateTime.now(),
        );
        await context.read<DebtProvider>().update(updated);
      } else {
        const uuid = Uuid();
        final debt = Debt(
          id: uuid.v4(),
          personName: _nameCtrl.text.trim(),
          direction: _direction,
          originalAmountCents: amountCents,
          paidAmountCents: 0,
          status: DebtStatus.unpaid,
          createdAt: DateTime.now(),
          description: _descCtrl.text.trim().isNotEmpty
              ? _descCtrl.text.trim()
              : null,
          notes: _notesCtrl.text.trim().isNotEmpty
              ? _notesCtrl.text.trim()
              : null,
          dueDate: _dueDate,
        );
        await context.read<DebtProvider>().add(debt);
      }
      HapticFeedback.mediumImpact();
      if (mounted) context.go('/profile/debts');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currency = context.watch<SettingsProvider>().currency;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Редактировать долг' : 'Новый долг'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            // Direction selector
            _label(context, 'Направление'),
            const SizedBox(height: AppSpacing.sm),
            _DirectionSelector(
              value: _direction,
              onChanged: (v) => setState(() => _direction = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'Имя / Название *'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _nameCtrl,
              style: TextStyle(color: colors.textPrimary),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  hintText: 'Кто должен или кому вы должны'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Обязательное поле' : null,
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
              decoration: const InputDecoration(hintText: '0.00'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Обязательное поле';
                final c = FinancialCalculator.parseAmountToCents(v);
                if (c == null || c <= 0) return 'Введите корректную сумму';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'Описание'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              style: TextStyle(color: colors.textPrimary),
              decoration:
                  const InputDecoration(hintText: 'За что долг...'),
            ),
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'Срок погашения'),
            const SizedBox(height: AppSpacing.xs),
            _DatePicker(
              value: _dueDate,
              onChanged: (d) => setState(() => _dueDate = d),
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
              label: _isEdit ? 'Сохранить' : 'Создать',
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

class _DirectionSelector extends StatelessWidget {
  const _DirectionSelector({required this.value, required this.onChanged});
  final DebtDirection value;
  final ValueChanged<DebtDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        Expanded(
          child: _DirectionOption(
            label: 'Мне должны',
            icon: Icons.trending_up_rounded,
            selected: value == DebtDirection.receivable,
            selectedColor: colors.income,
            onTap: () => onChanged(DebtDirection.receivable),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _DirectionOption(
            label: 'Я должен',
            icon: Icons.trending_down_rounded,
            selected: value == DebtDirection.payable,
            selectedColor: colors.expense,
            onTap: () => onChanged(DebtDirection.payable),
          ),
        ),
      ],
    );
  }
}

class _DirectionOption extends StatelessWidget {
  const _DirectionOption({
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
                size: 18,
                color: selected ? selectedColor : colors.textMuted),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
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

class _DatePicker extends StatelessWidget {
  const _DatePicker({required this.value, required this.onChanged});
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now().add(const Duration(days: 14)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
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
            Expanded(
              child: Text(
                value != null
                    ? '${value!.day.toString().padLeft(2, '0')}.${value!.month.toString().padLeft(2, '0')}.${value!.year}'
                    : 'Выберите дату (необязательно)',
                style: TextStyle(
                    fontSize: 14,
                    color: value != null
                        ? colors.textPrimary
                        : colors.textMuted),
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: Icon(Icons.close_rounded,
                    size: 16, color: colors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}
