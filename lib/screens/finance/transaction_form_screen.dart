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
import '../../l10n/app_tr.dart';

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
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
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
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _TransactionFormSheet extends StatefulWidget {
  const _TransactionFormSheet({this.transactionId, this.initialType});
  final String? transactionId;
  final TransactionType? initialType;

  @override
  State<_TransactionFormSheet> createState() => _TransactionFormSheetState();
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
  bool _dataLoading = false;
  AppTransaction? _existing;

  late final AnimationController _stagger;

  void _populateFromTransaction(AppTransaction found) {
    _existing = found;
    _type = found.type;
    final cents = found.amountCents;
    _amountCtrl.text = cents % 100 == 0
        ? (cents ~/ 100).toString()
        : (cents / 100).toStringAsFixed(2);
    _descCtrl.text = found.description ?? '';
    _notesCtrl.text = found.notes ?? '';
    _category = found.category;
    _date = found.date;
  }

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    if (widget.initialType != null) _type = widget.initialType!;

    if (widget.transactionId != null) {
      _isEdit = true;
      final financeProvider = context.read<FinanceProvider>();
      final cached = financeProvider.allTransactions
          .where((t) => t.id == widget.transactionId)
          .firstOrNull;

      if (cached != null) {
        // Populate synchronously before Frame 1!
        _populateFromTransaction(cached);
        _dataLoading = false;
        _stagger.forward();
      } else {
        // Show loading from Frame 1 (never empty inputs!)
        _dataLoading = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final found = await financeProvider.getById(widget.transactionId!);
          if (!mounted) return;
          if (found != null) {
            setState(() {
              _populateFromTransaction(found);
              _dataLoading = false;
            });
            _stagger.forward(from: 0);
          } else {
            setState(() => _dataLoading = false);
          }
        });
      }
    } else {
      _stagger.forward();
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
    final settings = context.watch<SettingsProvider>();
    final currency = settings.currency;
    final isIncome = _type == TransactionType.income;
    final accent = isIncome ? colors.income : colors.expense;

    final baseCategories =
        isIncome ? settings.incomeCategories : settings.expenseCategories;
    final categories = <String>[
      ...baseCategories,
      if (_category != null && !baseCategories.contains(_category)) _category!,
    ];

    return AppModalSheet(
      title: _isEdit
          ? context.tr('Изменить операцию', 'Edit transaction')
          : (isIncome
              ? context.tr('Новый доход', 'New income')
              : context.tr('Новый расход', 'New expense')),
      subtitle: _isEdit
          ? context.tr(
              'Сумма и дата обновят итог месяца',
              'Amount and date will update monthly total',
            )
          : (isIncome
              ? context.tr(
                  'Поступление средств в кассу бизнеса',
                  'Incoming funds to your business',
                )
              : context.tr(
                  'Списание средств на нужды бизнеса',
                  'Outgoing business expense',
                )),
      headerIcon:
          isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
      headerColor: accent,
      bottomBar: _dataLoading
          ? null
          : FormSubmitButton(
              label: _isEdit
                  ? context.tr('Сохранить изменения', 'Save changes')
                  : (isIncome
                      ? context.tr('Записать доход', 'Save income')
                      : context.tr('Записать расход', 'Save expense')),
              accentColor: accent,
              isLoading: _loading,
              onPressed: _save,
              icon: _isEdit ? Icons.check_rounded : Icons.add_rounded,
            ),
      body: _dataLoading
          ? SizedBox(
              height: 240,
              child: Center(
                child: CircularProgressIndicator(
                  color: accent,
                  strokeWidth: 2.5,
                ),
              ),
            )
          : Form(
              key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          shrinkWrap: true,
          children: [
            // 1. Type toggle
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
            const SizedBox(height: 16),

            // 2. Hero Amount Input
            FormStaggerItem(
              animation: _stagger,
              index: 1,
              child: SheetField(
                label: context.tr('СУММА ОПЕРАЦИИ', 'AMOUNT'),
                required: true,
                child: FormAmountField(
                  controller: _amountCtrl,
                  accentColor: accent,
                  prefix: isIncome ? '+' : '−',
                  currency: currency,
                  autofocus: !_isEdit,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Category chips with icons + Quick Add
            FormStaggerItem(
              animation: _stagger,
              index: 2,
              child: SheetField(
                label: context.tr('КАТЕГОРИЯ', 'CATEGORY'),
                trailingLabel: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.push(
                      '/profile/categories?type=${isIncome ? 'income' : 'expense'}',
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 13,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.tr('Управлять', 'Manage'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                child: _CategoryChipsSelector(
                  categories: categories,
                  type: _type,
                  selected: _category,
                  accentColor: accent,
                  onChanged: (c) => setState(() => _category = c),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Description
            FormStaggerItem(
              animation: _stagger,
              index: 3,
              child: SheetField(
                label: context.tr('НАЗВАНИЕ / ОПИСАНИЕ', 'TITLE / DESCRIPTION'),
                child: FormTextField(
                  controller: _descCtrl,
                  prefixIcon: Icons.edit_note_rounded,
                  hint: isIncome
                      ? context.tr(
                          'Например: Оплата за консультацию',
                          'e.g. Consultation fee',
                        )
                      : context.tr(
                          'Например: Закупка упаковки',
                          'e.g. Packaging supplies',
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 5. Date picker with quick chips
            FormStaggerItem(
              animation: _stagger,
              index: 4,
              child: SheetField(
                label: context.tr('ДАТА ОПЕРАЦИИ', 'DATE'),
                child: FormDatePicker(
                  value: _date,
                  onChanged: (d) => setState(() => _date = d ?? _date),
                  accentColor: accent,
                  allowPast: true,
                  nullable: false,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 6. Notes
            FormStaggerItem(
              animation: _stagger,
              index: 5,
              child: SheetField(
                label: context.tr('ЗАМЕТКИ', 'NOTES'),
                child: FormTextField(
                  controller: _notesCtrl,
                  prefixIcon: Icons.notes_rounded,
                  hint: context.tr(
                    'Комментарий или детали...',
                    'Comment or details...',
                  ),
                  maxLines: 2,
                ),
              ),
            ),
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
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
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
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: (isIncome ? colors.income : colors.expense)
                          .withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              _ToggleLabel(
                label: context.tr('Доход', 'Income'),
                icon: Icons.south_west_rounded,
                active: isIncome,
                onTap: () => onChanged(TransactionType.income),
              ),
              _ToggleLabel(
                label: context.tr('Расход', 'Expense'),
                icon: Icons.north_east_rounded,
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
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: active ? Colors.white : colors.textSecondary,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: active ? Colors.white : colors.textMuted,
                ),
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

// ─── Category chips with icons + Inline Quick Create ─────────────────────────

class _CategoryChipsSelector extends StatefulWidget {
  const _CategoryChipsSelector({
    required this.categories,
    required this.type,
    required this.selected,
    required this.accentColor,
    required this.onChanged,
  });

  final List<String> categories;
  final TransactionType type;
  final String? selected;
  final Color accentColor;
  final ValueChanged<String?> onChanged;

  @override
  State<_CategoryChipsSelector> createState() => _CategoryChipsSelectorState();
}

class _CategoryChipsSelectorState extends State<_CategoryChipsSelector> {
  bool _addingInline = false;
  final _newCatCtrl = TextEditingController();

  static const _meta = <String, (String, IconData)>{
    'order_payment': ('Оплата заказа', Icons.shopping_bag_outlined),
    'service': ('Услуга', Icons.handyman_outlined),
    'sale': ('Продажа', Icons.storefront_outlined),
    'refund_received': ('Возврат', Icons.replay_rounded),
    'other_income': ('Прочее', Icons.more_horiz_rounded),
    'supplies': ('Материалы', Icons.inventory_2_outlined),
    'rent': ('Аренда', Icons.home_work_outlined),
    'utilities': ('Коммуналка', Icons.bolt_rounded),
    'transport': ('Транспорт', Icons.local_shipping_outlined),
    'marketing': ('Маркетинг', Icons.campaign_outlined),
    'salary': ('Зарплата', Icons.badge_outlined),
    'equipment': ('Оборудование', Icons.precision_manufacturing_outlined),
    'other_expense': ('Прочее', Icons.more_horiz_rounded),
  };

  static const _metaEn = <String, (String, IconData)>{
    'order_payment': ('Order payment', Icons.shopping_bag_outlined),
    'service': ('Service', Icons.handyman_outlined),
    'sale': ('Sale', Icons.storefront_outlined),
    'refund_received': ('Refund', Icons.replay_rounded),
    'other_income': ('Other', Icons.more_horiz_rounded),
    'supplies': ('Supplies', Icons.inventory_2_outlined),
    'rent': ('Rent', Icons.home_work_outlined),
    'utilities': ('Utilities', Icons.bolt_rounded),
    'transport': ('Transport', Icons.local_shipping_outlined),
    'marketing': ('Marketing', Icons.campaign_outlined),
    'salary': ('Salary', Icons.badge_outlined),
    'equipment': ('Equipment', Icons.precision_manufacturing_outlined),
    'other_expense': ('Other', Icons.more_horiz_rounded),
  };

  @override
  void dispose() {
    _newCatCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitQuickCategory() async {
    final text = _newCatCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _addingInline = false);
      return;
    }
    HapticFeedback.mediumImpact();
    final createdKey = await context
        .read<SettingsProvider>()
        .addCategory(widget.type, text);
    if (!mounted) return;
    _newCatCtrl.clear();
    setState(() => _addingInline = false);
    if (createdKey != null) {
      widget.onChanged(createdKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ...widget.categories.map((cat) {
              final isSelected = widget.selected == cat;
              final iconData = _meta[cat]?.$2 ?? Icons.label_outline_rounded;
              final label = TransactionCategories.customLabels[cat] ??
                  (context.isEn ? _metaEn[cat]?.$1 : _meta[cat]?.$1) ??
                  TransactionCategories.labelFor(cat);

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onChanged(isSelected ? null : cat);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? widget.accentColor
                        : colors.surfaceSecondary.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? widget.accentColor : colors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle_rounded : iconData,
                        size: 15,
                        color: isSelected ? Colors.white : colors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // "+ Добавить" button right in the chips wrap
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _addingInline = !_addingInline);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _addingInline
                      ? colors.primary.withValues(alpha: 0.12)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.primary,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _addingInline ? Icons.close_rounded : Icons.add_rounded,
                      size: 15,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _addingInline
                          ? context.tr('Отмена', 'Cancel')
                          : context.tr('Своя категория', 'Custom'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Inline input when "+ Своя категория" is active
        if (_addingInline) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FormTextField(
                  controller: _newCatCtrl,
                  prefixIcon: Icons.label_outline_rounded,
                  hint: context.tr(
                    'Название новой категории...',
                    'New category name...',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                  onFieldSubmitted: (_) => _submitQuickCategory(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _submitQuickCategory,
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_rounded,
                          size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        context.tr('Создать', 'Create'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
