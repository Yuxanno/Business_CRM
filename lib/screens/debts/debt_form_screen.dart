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
import '../../components/app_modal_sheet.dart';
import '../../components/form_widgets.dart';

// ─── Route wrapper ────────────────────────────────────────────────────────────

class DebtFormScreen extends StatefulWidget {
  const DebtFormScreen({super.key, this.debtId});
  final String? debtId;

  @override
  State<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends State<DebtFormScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    await showAppModal<void>(
      context: context,
      child: _DebtFormSheet(debtId: widget.debtId),
    );
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profile/debts');
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: Colors.transparent);
}

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _DebtFormSheet extends StatefulWidget {
  const _DebtFormSheet({this.debtId});
  final String? debtId;

  @override
  State<_DebtFormSheet> createState() => _DebtFormSheetState();
}

class _DebtFormSheetState extends State<_DebtFormSheet>
    with SingleTickerProviderStateMixin {
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

  late AnimationController _stagger;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 560));
    _stagger.forward();

    if (widget.debtId != null) {
      _isEdit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final debt =
            await context.read<DebtProvider>().getById(widget.debtId!);
        if (debt != null && mounted) {
          setState(() {
            _existing = debt;
            _nameCtrl.text = debt.personName;
            _amountCtrl.text =
                (debt.originalAmountCents / 100).toStringAsFixed(2);
            _descCtrl.text = debt.description ?? '';
            _notesCtrl.text = debt.notes ?? '';
            _direction = debt.direction;
            _dueDate = debt.dueDate;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _stagger.dispose();
    _nameCtrl.dispose();
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
        await context.read<DebtProvider>().update(
              _existing!.copyWith(
                personName: _nameCtrl.text.trim(),
                direction: _direction,
                originalAmountCents: cents,
                description: _descCtrl.text.trim().isNotEmpty
                    ? _descCtrl.text.trim()
                    : null,
                notes: _notesCtrl.text.trim().isNotEmpty
                    ? _notesCtrl.text.trim()
                    : null,
                dueDate: _dueDate,
                updatedAt: DateTime.now(),
              ),
            );
      } else {
        await context.read<DebtProvider>().add(
              Debt(
                id: const Uuid().v4(),
                personName: _nameCtrl.text.trim(),
                direction: _direction,
                originalAmountCents: cents,
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
    final isReceivable = _direction == DebtDirection.receivable;
    final accent = isReceivable ? colors.income : colors.expense;

    return AppModalSheet(
      title: _isEdit ? 'Редактировать долг' : 'Новый долг',
      subtitle: _isEdit
          ? 'Сумма и срок обновят карточку долга'
          : (isReceivable
              ? 'Этот человек должен вам. Срок поможет не забыть о возврате.'
              : 'Вы должны этому человеку. Срок покажет, когда платить.'),
      headerIcon: isReceivable
          ? Icons.arrow_downward_rounded
          : Icons.arrow_upward_rounded,
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
            // Direction
            FormStaggerItem(
              animation: _stagger,
              index: 0,
              child: SheetField(
                label: 'КТО КОМУ ДОЛЖЕН',
                child: _DirectionToggle(
                  value: _direction,
                  onChanged: (v) => setState(() => _direction = v),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Name
            FormStaggerItem(
              animation: _stagger,
              index: 1,
              child: SheetField(
                label: 'ИМЯ / КОМПАНИЯ',
                required: true,
                child: FormTextField(
                  controller: _nameCtrl,
                  hint: isReceivable ? 'Кто вам должен...' : 'Кому вы должны...',
                  textCapitalization: TextCapitalization.words,
                  autofocus: !_isEdit,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Введите имя' : null,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Amount
            FormStaggerItem(
              animation: _stagger,
              index: 2,
              child: SheetField(
                label: 'СУММА ($currency)',
                required: true,
                child: FormAmountField(
                  controller: _amountCtrl,
                  accentColor: accent,
                  prefix: isReceivable ? '+' : '−',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Description
            FormStaggerItem(
              animation: _stagger,
              index: 3,
              child: SheetField(
                label: 'ЗА ЧТО',
                child: FormTextField(
                  controller: _descCtrl,
                  hint: 'Описание долга...',
                  maxLines: 2,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Due date
            FormStaggerItem(
              animation: _stagger,
              index: 4,
              child: SheetField(
                label: 'СРОК ПОГАШЕНИЯ',
                child: FormDatePicker(
                  value: _dueDate,
                  onChanged: (d) => setState(() => _dueDate = d),
                  accentColor: colors.warning,
                  nullable: true,
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
                label: _isEdit ? 'Сохранить' : 'Создать запись',
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

// ─── Direction animated toggle ────────────────────────────────────────────────

class _DirectionToggle extends StatelessWidget {
  const _DirectionToggle({required this.value, required this.onChanged});
  final DebtDirection value;
  final ValueChanged<DebtDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isReceivable = value == DebtDirection.receivable;

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
            alignment: isReceivable
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: isReceivable ? colors.income : colors.expense,
                  borderRadius:
                      BorderRadius.circular(AppRadius.md - 2),
                  boxShadow: [
                    BoxShadow(
                      color: (isReceivable ? colors.income : colors.expense)
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
              _DirLabel(
                label: 'Мне должны',
                icon: Icons.arrow_downward_rounded,
                active: isReceivable,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(DebtDirection.receivable);
                },
              ),
              _DirLabel(
                label: 'Я должен',
                icon: Icons.arrow_upward_rounded,
                active: !isReceivable,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(DebtDirection.payable);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DirLabel extends StatelessWidget {
  const _DirLabel({
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
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? Colors.white : colors.textSecondary,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 14,
                    color: active ? Colors.white : colors.textMuted),
                const SizedBox(width: 4),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
