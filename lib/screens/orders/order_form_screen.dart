import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/order.dart';
import '../../models/customer.dart';
import '../../providers/order_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../components/app_modal_sheet.dart';
import '../../components/app_avatar.dart';
import '../../components/form_widgets.dart';
import '../../components/voice_note_field.dart';
import '../../l10n/app_tr.dart';

// ─── Route wrapper ────────────────────────────────────────────────────────────

class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key, this.orderId});
  final String? orderId;

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    await showAppModal<void>(
      context: context,
      child: _OrderFormSheet(orderId: widget.orderId),
    );
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/orders');
      }
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _OrderFormSheet extends StatefulWidget {
  const _OrderFormSheet({this.orderId});
  final String? orderId;

  @override
  State<_OrderFormSheet> createState() => _OrderFormSheetState();
}

class _OrderFormSheetState extends State<_OrderFormSheet>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  Customer? _selectedCustomer;
  DateTime? _dueDate;
  OrderStatus _status = OrderStatus.newOrder;
  bool _loading = false;
  bool _isEdit = false;
  bool _dataLoading = false;
  Order? _existingOrder;
  bool _customerError = false;

  late final AnimationController _stagger;

  void _populateFromOrder(Order order, List<Customer> allCustomers) {
    _existingOrder = order;
    _titleCtrl.text = order.title;
    final cents = order.totalPriceCents;
    _priceCtrl.text = cents % 100 == 0
        ? (cents ~/ 100).toString()
        : (cents / 100).toStringAsFixed(2);
    _descCtrl.text = order.description ?? '';
    _notesCtrl.text = order.notes ?? '';
    _dueDate = order.dueDate;
    _status = order.status;
    _selectedCustomer = allCustomers
            .where((c) => c.id == order.customerId)
            .firstOrNull ??
        Customer(
          id: order.customerId,
          name: order.customerName,
          createdAt: order.createdAt,
        );
  }

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    final orderProvider = context.read<OrderProvider>();
    final customerProvider = context.read<CustomerProvider>();

    if (widget.orderId != null) {
      _isEdit = true;
      final cachedOrder = orderProvider.allOrders
          .where((o) => o.id == widget.orderId)
          .firstOrNull;

      if (cachedOrder != null) {
        // Data is already in memory — populate synchronously before Frame 1!
        _populateFromOrder(cachedOrder, customerProvider.allCustomers);
        _dataLoading = false;
        _stagger.forward();
      } else {
        // Not in memory yet — show loading from Frame 1 (never empty inputs!)
        _dataLoading = true;
      }
    } else {
      _stagger.forward();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (customerProvider.allCustomers.isEmpty) {
        await customerProvider.load();
      }
      if (!mounted) return;

      if (widget.orderId != null && _dataLoading) {
        final order = await orderProvider.getById(widget.orderId!);
        if (!mounted) return;
        if (order != null) {
          final customer = customerProvider.allCustomers
                  .where((c) => c.id == order.customerId)
                  .firstOrNull ??
              await customerProvider.getById(order.customerId);
          if (!mounted) return;
          setState(() {
            _populateFromOrder(order, customerProvider.allCustomers);
            if (customer != null) _selectedCustomer = customer;
            _dataLoading = false;
          });
          _stagger.forward(from: 0);
        } else {
          setState(() => _dataLoading = false);
        }
      } else if (_isEdit && _existingOrder != null) {
        // Enrich _selectedCustomer if full customer object loaded in background
        final fullCustomer = customerProvider.allCustomers
            .where((c) => c.id == _existingOrder!.customerId)
            .firstOrNull;
        if (fullCustomer != null && mounted) {
          setState(() => _selectedCustomer = fullCustomer);
        }
      }
    });
  }

  @override
  void dispose() {
    _stagger.dispose();
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedCustomer == null) {
      HapticFeedback.vibrate();
      setState(() => _customerError = true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final price = FinancialCalculator.parseAmountToCents(_priceCtrl.text);
    if (price == null || price <= 0) return;

    setState(() => _loading = true);
    try {
      if (_isEdit && _existingOrder != null) {
        await context.read<OrderProvider>().update(
              _existingOrder!.copyWith(
                title: _titleCtrl.text.trim(),
                customerId: _selectedCustomer!.id,
                customerName: _selectedCustomer!.name,
                totalPriceCents: price,
                description: _descCtrl.text.trim().isNotEmpty
                    ? _descCtrl.text.trim()
                    : null,
                notes: _notesCtrl.text.trim().isNotEmpty
                    ? _notesCtrl.text.trim()
                    : null,
                dueDate: _dueDate,
                status: _status,
                updatedAt: DateTime.now(),
              ),
            );
      } else {
        await context.read<OrderProvider>().add(
              Order(
                id: const Uuid().v4(),
                title: _titleCtrl.text.trim(),
                customerId: _selectedCustomer!.id,
                customerName: _selectedCustomer!.name,
                totalPriceCents: price,
                receivedCents: 0,
                status: _status,
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
    final customers = context.watch<CustomerProvider>().customers;

    return AppModalSheet(
      title: _isEdit
          ? context.tr('Редактировать заказ', 'Edit order')
          : context.tr('Новый заказ', 'New order'),
      subtitle: _isEdit
          ? context.tr('Сумма и срок обновятся в карточке заказа',
              'Amount and deadline will update in the order card')
          : context.tr('Укажите клиента, стоимость и дедлайн выполнения',
              'Specify the customer, price, and deadline'),
      headerIcon: Icons.shopping_bag_outlined,
      headerColor: colors.primary,
      bottomBar: _dataLoading
          ? null
          : FormSubmitButton(
              label: _isEdit
                  ? context.tr('Сохранить изменения', 'Save changes')
                  : context.tr('Создать заказ', 'Create order'),
              accentColor: colors.primary,
              isLoading: _loading,
              onPressed: _save,
              icon: _isEdit ? Icons.check_rounded : Icons.add_rounded,
            ),
      body: _dataLoading
          ? SizedBox(
              height: 260,
              child: Center(
                child: CircularProgressIndicator(
                  color: colors.primary,
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
                  // 1. Title
                  FormStaggerItem(
                    animation: _stagger,
                    index: 0,
                    child: SheetField(
                      label: context.tr('НАЗВАНИЕ ЗАКАЗА', 'ORDER TITLE'),
                      required: true,
                      child: FormTextField(
                        controller: _titleCtrl,
                        prefixIcon: Icons.shopping_bag_outlined,
                        hint: context.tr('Например: Разработка логотипа',
                            'e.g., Logo design'),
                        textCapitalization: TextCapitalization.sentences,
                        autofocus: !_isEdit,
                        textInputAction: TextInputAction.done,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? context.tr('Введите название заказа',
                                'Enter order title')
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Customer picker
                  FormStaggerItem(
                    animation: _stagger,
                    index: 1,
                    child: SheetField(
                      label: context.tr('КЛИЕНТ', 'CUSTOMER'),
                      required: true,
                      child: _CustomerTile(
                        customers: customers,
                        selected: _selectedCustomer,
                        hasError: _customerError,
                        onChanged: (c) => setState(() {
                          _selectedCustomer = c;
                          _customerError = false;
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Price (Currency-aware!)
                  FormStaggerItem(
                    animation: _stagger,
                    index: 2,
                    child: SheetField(
                      label: context.tr('СТОИМОСТЬ ЗАКАЗА', 'ORDER PRICE'),
                      required: true,
                      child: FormAmountField(
                        controller: _priceCtrl,
                        accentColor: colors.primary,
                        prefix: '¤',
                        currency: currency,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Deadline
                  FormStaggerItem(
                    animation: _stagger,
                    index: 3,
                    child: SheetField(
                      label: context.tr('ДЕДЛАЙН (СРОК СДАЧИ)', 'DEADLINE'),
                      child: FormDatePicker(
                        value: _dueDate,
                        onChanged: (d) => setState(() => _dueDate = d),
                        accentColor: colors.warning,
                        nullable: true,
                      ),
                    ),
                  ),

                  // 5. Status (edit only)
                  if (_isEdit) ...[
                    const SizedBox(height: 16),
                    FormStaggerItem(
                      animation: _stagger,
                      index: 4,
                      child: SheetField(
                        label: context.tr('СТАТУС ЗАКАЗА', 'ORDER STATUS'),
                        child: _StatusChips(
                          value: _status,
                          onChanged: (s) => setState(() => _status = s),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 6. Description
                  FormStaggerItem(
                    animation: _stagger,
                    index: 5,
                    child: SheetField(
                      label: context.tr('ОПИСАНИЕ РАБОТЫ', 'WORK DESCRIPTION'),
                      child: VoiceNoteField(
                        controller: _descCtrl,
                        prefixIcon: Icons.description_outlined,
                        hint: context.tr(
                            'Что нужно сделать...', 'What needs to be done...'),
                        minLines: 2,
                        maxLines: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 7. Notes
                  FormStaggerItem(
                    animation: _stagger,
                    index: 6,
                    child: SheetField(
                      label: context.tr('ВНУТРЕННИЕ ЗАМЕТКИ', 'INTERNAL NOTES'),
                      child: VoiceNoteField(
                        controller: _notesCtrl,
                        prefixIcon: Icons.notes_rounded,
                        hint: context.tr(
                            'Комментарий для себя...', 'Note for yourself...'),
                        minLines: 2,
                        maxLines: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── Customer tile / picker ───────────────────────────────────────────────────

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customers,
    required this.selected,
    required this.hasError,
    required this.onChanged,
  });

  final List<Customer> customers;
  final Customer? selected;
  final bool hasError;
  final ValueChanged<Customer?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (selected != null) {
      return GestureDetector(
        onTap: () => _openPicker(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              AppAvatar(name: selected!.name, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (selected!.phone != null && selected!.phone!.isNotEmpty)
                      Text(
                        selected!.phone!,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  context.tr('Сменить', 'Change'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _openPicker(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: hasError
                  ? colors.expense.withValues(alpha: 0.06)
                  : colors.surfaceSecondary.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasError ? colors.expense : colors.border,
                width: hasError ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: hasError
                        ? colors.expense.withValues(alpha: 0.12)
                        : colors.surface,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.person_search_rounded,
                    size: 17,
                    color: hasError ? colors.expense : colors.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr(
                        'Выберите клиента из базы', 'Select a customer'),
                    style: TextStyle(
                      fontSize: 14,
                      color: hasError ? colors.expense : colors.textMuted,
                      fontWeight:
                          hasError ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (hasError)
          FormFieldError(
              text: context.tr(
                  'Пожалуйста, выберите клиента', 'Please select a customer')),
      ],
    );
  }

  void _openPicker(BuildContext context) {
    HapticFeedback.selectionClick();
    showAppModal<Customer>(
      context: context,
      child: _CustomerPickerSheet(
        customers: customers,
        selected: selected,
        onPick: (c) {
          onChanged(c);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet({
    required this.customers,
    required this.selected,
    required this.onPick,
  });

  final List<Customer> customers;
  final Customer? selected;
  final ValueChanged<Customer> onPick;

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _q = '';
  bool _creatingInline = false;
  final _newNameCtrl = TextEditingController();
  final _newPhoneCtrl = TextEditingController();
  bool _savingNew = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _newNameCtrl.dispose();
    _newPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _quickCreateCustomer() async {
    final name = _newNameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _savingNew = true);
    try {
      final newCustomer = Customer(
        id: const Uuid().v4(),
        name: name,
        phone: _newPhoneCtrl.text.trim().isNotEmpty
            ? _newPhoneCtrl.text.trim()
            : null,
        createdAt: DateTime.now(),
      );
      await context.read<CustomerProvider>().add(newCustomer);
      HapticFeedback.mediumImpact();
      if (mounted) {
        widget.onPick(newCustomer);
      }
    } finally {
      if (mounted) setState(() => _savingNew = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final allCustomers = context.watch<CustomerProvider>().customers;
    final source = allCustomers.isNotEmpty ? allCustomers : widget.customers;
    final filtered = source
        .where((c) =>
            c.name.toLowerCase().contains(_q.toLowerCase()) ||
            (c.phone?.toLowerCase().contains(_q.toLowerCase()) ?? false))
        .toList();

    return AppModalSheet(
      title: _creatingInline
          ? context.tr('Быстрое создание клиента', 'Quick create customer')
          : context.tr('Выбор клиента', 'Select customer'),
      subtitle: _creatingInline
          ? context.tr('Клиент сразу привяжется к этому заказу',
              'Customer will be linked to this order')
          : context.tr('Найдите клиента или добавьте нового за пару секунд',
              'Find a customer or add a new one in seconds'),
      headerIcon: _creatingInline
          ? Icons.person_add_alt_1_rounded
          : Icons.people_alt_outlined,
      headerColor: colors.primary,
      maxHeightFactor: 0.78,
      bottomBar: _creatingInline
          ? Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _creatingInline = false),
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        context.tr('Назад к списку', 'Back to list'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FormSubmitButton(
                    label: context.tr('Создать и выбрать', 'Create & select'),
                    accentColor: colors.primary,
                    isLoading: _savingNew,
                    onPressed: _quickCreateCustomer,
                    icon: Icons.check_rounded,
                  ),
                ),
              ],
            )
          : null,
      body: _creatingInline
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SheetField(
                    label: context.tr('ИМЯ КЛИЕНТА', 'CUSTOMER NAME'),
                    required: true,
                    child: FormTextField(
                      controller: _newNameCtrl,
                      prefixIcon: Icons.person_outline_rounded,
                      hint: context.tr(
                          'Например: Алишер Каримов', 'e.g., Alexey Ivanov'),
                      textCapitalization: TextCapitalization.words,
                      autofocus: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SheetField(
                    label: context.tr('ТЕЛЕФОН', 'PHONE'),
                    child: FormTextField(
                      controller: _newPhoneCtrl,
                      prefixIcon: Icons.phone_outlined,
                      hint: '+998 90 000 00 00',
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search + Quick Add button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                colors.surfaceSecondary.withValues(alpha: 0.7),
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
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 11),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _newNameCtrl.text = _q;
                          setState(() => _creatingInline = true);
                        },
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_add_alt_1_rounded,
                                size: 16,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                context.tr('Новый', 'New'),
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
                ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 28,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_off_outlined,
                          size: 32,
                          color: colors.textMuted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr(
                              'Клиенты не найдены', 'No customers found'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr(
                              'Нажмите «Новый», чтобы быстро создать клиента',
                              'Tap "New" to quickly create a customer'),
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final sel = widget.selected?.id == c.id;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.onPick(c);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: sel
                                  ? colors.primary.withValues(alpha: 0.08)
                                  : colors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: sel ? colors.primary : colors.border,
                                width: sel ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                AppAvatar(name: c.name, size: 38),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          c.phone!.isNotEmpty)
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
                                Icon(
                                  sel
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: sel
                                      ? colors.primary
                                      : colors.border,
                                  size: 20,
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

// ─── Status chips ─────────────────────────────────────────────────────────────

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.value, required this.onChanged});
  final OrderStatus value;
  final ValueChanged<OrderStatus> onChanged;

  static Map<OrderStatus, (String, IconData, Color)> get _items => {
        OrderStatus.newOrder: (
          AppTr.tr('Новый', 'New'),
          Icons.fiber_new_rounded,
          const Color(0xFF0F766E)
        ),
        OrderStatus.inProgress: (
          AppTr.tr('В работе', 'In progress'),
          Icons.play_circle_rounded,
          const Color(0xFF14B8A6)
        ),
        OrderStatus.completed: (
          AppTr.tr('Завершён', 'Completed'),
          Icons.check_circle_rounded,
          const Color(0xFF10B981)
        ),
        OrderStatus.cancelled: (
          AppTr.tr('Отменён', 'Cancelled'),
          Icons.cancel_rounded,
          const Color(0xFF94A3B8)
        ),
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: OrderStatus.values.map((s) {
        final item = _items[s]!;
        final sel = value == s;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(s);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: sel
                  ? item.$3.withValues(alpha: 0.14)
                  : colors.surfaceSecondary.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel ? item.$3 : colors.border,
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.$2,
                  size: 15,
                  color: sel ? item.$3 : colors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  item.$1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? item.$3 : colors.textPrimary,
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
