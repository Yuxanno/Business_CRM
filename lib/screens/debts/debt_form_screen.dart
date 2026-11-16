import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../models/debt.dart';
import '../../models/customer.dart';
import '../../providers/debt_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../components/app_avatar.dart';
import '../../components/app_modal_sheet.dart';
import '../../components/form_widgets.dart';
import '../../l10n/app_tr.dart';

// ─── Route wrapper ────────────────────────────────────────────────────────────

class DebtFormScreen extends StatefulWidget {
  const DebtFormScreen({super.key, this.debtId, this.initialDirection});
  final String? debtId;
  final DebtDirection? initialDirection;

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
      child: _DebtFormSheet(
        debtId: widget.debtId,
        initialDirection: widget.initialDirection,
      ),
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
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _DebtFormSheet extends StatefulWidget {
  const _DebtFormSheet({this.debtId, this.initialDirection});
  final String? debtId;
  final DebtDirection? initialDirection;

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
  String? _selectedCustomerId;
  bool _loading = false;
  bool _isEdit = false;
  bool _dataLoading = false;
  Debt? _existing;

  late final AnimationController _stagger;

  void _populateFromDebt(Debt debt) {
    _existing = debt;
    _nameCtrl.text = debt.personName;
    _selectedCustomerId = debt.customerId;
    final cents = debt.originalAmountCents;
    _amountCtrl.text = cents % 100 == 0
        ? (cents ~/ 100).toString()
        : (cents / 100).toStringAsFixed(2);
    _descCtrl.text = debt.description ?? '';
    _notesCtrl.text = debt.notes ?? '';
    _direction = debt.direction;
    _dueDate = debt.dueDate;
  }

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _nameCtrl.addListener(_onNameChanged);

    // Ensure customers are loaded so user can pick from database
    final customerProvider = context.read<CustomerProvider>();
    if (customerProvider.allCustomers.isEmpty && !customerProvider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<CustomerProvider>().load();
        }
      });
    }

    if (widget.debtId != null) {
      _isEdit = true;
      final debtProvider = context.read<DebtProvider>();
      final cached = debtProvider.all
          .where((d) => d.id == widget.debtId)
          .firstOrNull;

      if (cached != null) {
        // Populate synchronously before Frame 1!
        _populateFromDebt(cached);
        _dataLoading = false;
        _stagger.forward();
      } else {
        // Show loading from Frame 1 (never empty inputs!)
        _dataLoading = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final debt = await debtProvider.getById(widget.debtId!);
          if (!mounted) return;
          if (debt != null) {
            setState(() {
              _populateFromDebt(debt);
              _dataLoading = false;
            });
            _stagger.forward(from: 0);
          } else {
            setState(() => _dataLoading = false);
          }
        });
      }
    } else {
      _direction = widget.initialDirection ??
          context.read<DebtProvider>().selectedDirection;
      _stagger.forward();
    }
  }

  void _onNameChanged() {
    if (!mounted) return;
    final customers = context.read<CustomerProvider>().allCustomers;
    final typed = _nameCtrl.text.trim().toLowerCase();
    if (_selectedCustomerId != null) {
      final matched = customers
          .where((c) => c.id == _selectedCustomerId)
          .firstOrNull;
      if (matched == null || matched.name.trim().toLowerCase() != typed) {
        setState(() => _selectedCustomerId = null);
        return;
      }
    } else {
      final exactMatch = customers
          .where((c) => c.name.trim().toLowerCase() == typed)
          .firstOrNull;
      if (exactMatch != null) {
        setState(() => _selectedCustomerId = exactMatch.id);
        return;
      }
    }
    setState(() {});
  }

  void _selectCustomer(Customer customer) {
    HapticFeedback.selectionClick();
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.text = customer.name;
    _nameCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _nameCtrl.text.length),
    );
    _nameCtrl.addListener(_onNameChanged);
    setState(() {
      _selectedCustomerId = customer.id;
    });
  }

  void _openCustomerPicker(List<Customer> customers, Color accent) {
    HapticFeedback.selectionClick();
    showAppModal<Customer>(
      context: context,
      child: _DebtCustomerPickerSheet(
        customers: customers,
        selectedId: _selectedCustomerId,
        accentColor: accent,
        onPick: (c) {
          _selectCustomer(c);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
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
                customerId: _selectedCustomerId,
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
                customerId: _selectedCustomerId,
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
    final allCustomers = context.watch<CustomerProvider>().allCustomers;
    final isReceivable = _direction == DebtDirection.receivable;
    final accent = isReceivable ? colors.income : colors.expense;

    final query = _nameCtrl.text.trim().toLowerCase();
    final suggestedCustomers = query.isEmpty
        ? allCustomers.take(6).toList()
        : allCustomers
            .where(
              (c) =>
                  c.name.toLowerCase().contains(query) ||
                  (c.phone?.toLowerCase().contains(query) ?? false),
            )
            .take(6)
            .toList();

    return AppModalSheet(
      title: _isEdit
          ? context.tr('Редактировать долг', 'Edit debt')
          : context.tr('Новая запись долга', 'New debt'),
      subtitle: _isEdit
          ? context.tr('Сумма и срок обновят карточку долга',
              'Amount and due date will update the debt card')
          : (isReceivable
              ? context.tr('Дебиторский долг — ожидается возврат вам',
                  'Receivable — money owed to you')
              : context.tr('Кредиторский долг — нужно вернуть контрагенту',
                  'Payable — money you owe')),
      headerIcon: isReceivable
          ? Icons.south_west_rounded
          : Icons.north_east_rounded,
      headerColor: accent,
      bottomBar: _dataLoading
          ? null
          : FormSubmitButton(
              label: _isEdit
                  ? context.tr('Сохранить изменения', 'Save changes')
                  : context.tr('Зафиксировать долг', 'Save debt'),
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
                  // 1. Direction toggle (only when creating a new debt)
                  if (!_isEdit) ...[
                    FormStaggerItem(
                      animation: _stagger,
                      index: 0,
                      child: SheetField(
                        label: context.tr('НАПРАВЛЕНИЕ ДОЛГА', 'DEBT TYPE'),
                        child: _DirectionToggle(
                          value: _direction,
                          onChanged: (v) => setState(() => _direction = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 2. Amount
                  FormStaggerItem(
                    animation: _stagger,
                    index: 1,
                    child: SheetField(
                      label: context.tr('СУММА ДОЛГА', 'DEBT AMOUNT'),
                      required: true,
                      child: FormAmountField(
                        controller: _amountCtrl,
                        accentColor: accent,
                        prefix: isReceivable ? '+' : '−',
                        currency: currency,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Person / Company Name + Pick from Customers DB
                  FormStaggerItem(
                    animation: _stagger,
                    index: 2,
                    child: SheetField(
                      label: context.tr('КТО / КОМУ (ИМЯ ИЛИ КОМПАНИЯ)',
                          'WHO / COUNTERPARTY'),
                      required: true,
                      trailingLabel: GestureDetector(
                        onTap: () => _openCustomerPicker(allCustomers, accent),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.people_alt_outlined,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.tr('Выбрать из базы', 'Pick customer'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FormTextField(
                            controller: _nameCtrl,
                            prefixIcon: _selectedCustomerId != null
                                ? Icons.how_to_reg_rounded
                                : Icons.person_outline_rounded,
                            hint: isReceivable
                                ? context.tr(
                                    'Введите имя или выберите клиента...',
                                    'Enter name or pick a customer...')
                                : context.tr(
                                    'Кому вы должны (имя или из базы)...',
                                    'Who you owe (name or pick customer)...'),
                            textCapitalization: TextCapitalization.words,
                            autofocus: !_isEdit,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? context.tr('Укажите имя', 'Enter a name')
                                : null,
                          ),
                          if (suggestedCustomers.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 30,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: suggestedCustomers.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 6),
                                itemBuilder: (context, i) {
                                  final c = suggestedCustomers[i];
                                  final isSelected =
                                      _selectedCustomerId == c.id;
                                  return GestureDetector(
                                    onTap: () => _selectCustomer(c),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 160),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? accent
                                            : colors.surfaceSecondary,
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: isSelected
                                              ? accent
                                              : colors.border,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSelected
                                                ? Icons.check_circle_rounded
                                                : Icons.person_outline_rounded,
                                            size: 13,
                                            color: isSelected
                                                ? Colors.white
                                                : colors.textSecondary,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            c.name,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                              color: isSelected
                                                  ? Colors.white
                                                  : colors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Due date
                  FormStaggerItem(
                    animation: _stagger,
                    index: 3,
                    child: SheetField(
                      label: context.tr('СРОК ВОЗВРАТА', 'DUE DATE'),
                      child: FormDatePicker(
                        value: _dueDate,
                        onChanged: (d) => setState(() => _dueDate = d),
                        accentColor: colors.warning,
                        nullable: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Reason / Description
                  FormStaggerItem(
                    animation: _stagger,
                    index: 4,
                    child: SheetField(
                      label: context.tr('ОСНОВАНИЕ / ЗА ЧТО', 'REASON'),
                      child: FormTextField(
                        controller: _descCtrl,
                        prefixIcon: Icons.edit_note_rounded,
                        hint: context.tr(
                            'Например: Отсрочка за партию товара',
                            'e.g., Deferred payment for goods'),
                        textInputAction: TextInputAction.next,
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
                        hint: context.tr('Условия возврата или контакты...',
                            'Repayment terms or contacts...'),
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

// ─── Customer Picker Sheet for Debt Form ─────────────────────────────────────

class _DebtCustomerPickerSheet extends StatefulWidget {
  const _DebtCustomerPickerSheet({
    required this.customers,
    required this.selectedId,
    required this.accentColor,
    required this.onPick,
  });

  final List<Customer> customers;
  final String? selectedId;
  final Color accentColor;
  final ValueChanged<Customer> onPick;

  @override
  State<_DebtCustomerPickerSheet> createState() =>
      _DebtCustomerPickerSheetState();
}

class _DebtCustomerPickerSheetState extends State<_DebtCustomerPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final allCustomers = context.watch<CustomerProvider>().allCustomers;
    final source = allCustomers.isNotEmpty ? allCustomers : widget.customers;
    final filtered = source
        .where(
          (c) =>
              c.name.toLowerCase().contains(_q.toLowerCase()) ||
              (c.phone?.toLowerCase().contains(_q.toLowerCase()) ?? false),
        )
        .toList();

    return AppModalSheet(
      title: context.tr('Выбрать из базы клиентов', 'Pick from customers'),
      subtitle: context.tr(
          'Выберите клиента или закройте окно для ручного ввода имени',
          'Select a customer or close to enter a name manually'),
      headerIcon: Icons.people_alt_outlined,
      headerColor: colors.primary,
      maxHeightFactor: 0.75,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: colors.surfaceSecondary.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _q = v),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: context.tr('Поиск по имени или телефону...',
                      'Search by name or phone...'),
                  hintStyle: TextStyle(
                    color: colors.textMuted,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: colors.textMuted,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 32,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 36,
                    color: colors.textMuted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    source.isEmpty
                        ? context.tr(
                            'База клиентов пока пуста', 'No customers yet')
                        : context.tr('Клиенты не найдены', 'No customers found'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(
                        'Вы можете просто вписать любое имя вручную в поле формы',
                        'You can simply type any name manually in the form'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = filtered[i];
                  final isSelected = c.id == widget.selectedId;
                  return GestureDetector(
                    onTap: () => widget.onPick(c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primary.withValues(alpha: 0.08)
                            : colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? colors.primary : colors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          AppAvatar(name: c.name, size: 38),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                if (c.phone != null &&
                                    c.phone!.trim().isNotEmpty)
                                  Text(
                                    c.phone!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: colors.primary,
                              size: 20,
                            )
                          else
                            Icon(
                              Icons.chevron_right_rounded,
                              color: colors.textMuted,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
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
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: isReceivable
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isReceivable ? colors.income : colors.expense,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: (isReceivable ? colors.income : colors.expense)
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
              _DirLabel(
                label: context.tr('Мне должны', 'Owed to me'),
                icon: Icons.south_west_rounded,
                active: isReceivable,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(DebtDirection.receivable);
                },
              ),
              _DirLabel(
                label: context.tr('Я должен', 'I owe'),
                icon: Icons.north_east_rounded,
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
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: active ? Colors.white : colors.textSecondary,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: active ? Colors.white : colors.textMuted,
                ),
                const SizedBox(width: 5),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
