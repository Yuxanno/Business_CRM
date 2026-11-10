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
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: Colors.transparent);
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

  late AnimationController _stagger;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _stagger.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final customerProvider = context.read<CustomerProvider>();
      final orderProvider = context.read<OrderProvider>();
      await customerProvider.load();
      if (widget.orderId != null) {
        _isEdit = true;
        if (mounted) setState(() => _dataLoading = true);
        final order = await orderProvider.getById(widget.orderId!);
        if (order != null && mounted) {
          final customer = await customerProvider.getById(order.customerId);
          if (mounted) {
            setState(() {
              _existingOrder = order;
              _titleCtrl.text = order.title;
              _priceCtrl.text =
                  (order.totalPriceCents / 100).toStringAsFixed(2);
              _descCtrl.text = order.description ?? '';
              _notesCtrl.text = order.notes ?? '';
              _dueDate = order.dueDate;
              _status = order.status;
              _selectedCustomer = customer;
              _dataLoading = false;
            });
          }
        } else if (mounted) {
          setState(() => _dataLoading = false);
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
      title: _isEdit ? 'Редактировать заказ' : 'Новый заказ',
      subtitle: _isEdit
          ? 'Сумма и срок обновятся в карточке заказа'
          : 'Укажите клиента, сумму и срок. Статус можно сменить в карточке.',
      headerIcon: Icons.receipt_long_rounded,
      headerColor: colors.primary,
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
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl + MediaQuery.of(context).viewInsets.bottom,
          ),
          shrinkWrap: true,
          children: [
            // Title
            FormStaggerItem(
              animation: _stagger,
              index: 0,
              child: SheetField(
                label: 'НАЗВАНИЕ ЗАКАЗА',
                required: true,
                child: FormTextField(
                  controller: _titleCtrl,
                  hint: 'Например: Разработка логотипа',
                  autofocus: !_isEdit,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Введите название'
                      : null,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Customer picker
            FormStaggerItem(
              animation: _stagger,
              index: 1,
              child: SheetField(
                label: 'КЛИЕНТ',
                required: true,
                child: _CustomerTile(
                  customers: customers,
                  selected: _selectedCustomer,
                  hasError: _customerError,
                  onChanged: (c) =>
                      setState(() {
                        _selectedCustomer = c;
                        _customerError = false;
                      }),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Price
            FormStaggerItem(
              animation: _stagger,
              index: 2,
              child: SheetField(
                label: 'СТОИМОСТЬ ($currency)',
                required: true,
                child: FormAmountField(
                  controller: _priceCtrl,
                  accentColor: colors.primary,
                  prefix: '₽',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Description
            FormStaggerItem(
              animation: _stagger,
              index: 3,
              child: SheetField(
                label: 'ОПИСАНИЕ РАБОТЫ',
                child: FormTextField(
                  controller: _descCtrl,
                  hint: 'Что нужно сделать...',
                  maxLines: 3,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Deadline
            FormStaggerItem(
              animation: _stagger,
              index: 4,
              child: SheetField(
                label: 'ДЕДЛАЙН',
                child: FormDatePicker(
                  value: _dueDate,
                  onChanged: (d) => setState(() => _dueDate = d),
                  accentColor: colors.warning,
                  nullable: true,
                ),
              ),
            ),

            // Status (edit only)
            if (_isEdit) ...[
              const SizedBox(height: AppSpacing.lg),
              FormStaggerItem(
                animation: _stagger,
                index: 5,
                child: SheetField(
                  label: 'СТАТУС',
                  child: _StatusChips(
                    value: _status,
                    onChanged: (s) => setState(() => _status = s),
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            // Notes
            FormStaggerItem(
              animation: _stagger,
              index: 6,
              child: SheetField(
                label: 'ЗАМЕТКИ',
                child: FormTextField(
                  controller: _notesCtrl,
                  hint: 'Внутренние заметки...',
                  maxLines: 2,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            FormStaggerItem(
              animation: _stagger,
              index: 7,
              child: FormSubmitButton(
                label: _isEdit ? 'Сохранить' : 'Создать заказ',
                accentColor: colors.primary,
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

    // Show selected customer as card
    if (selected != null) {
      return GestureDetector(
        onTap: () => _openPicker(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border:
                Border.all(color: colors.primary, width: 1.5),
          ),
          child: Row(
            children: [
              AppAvatar(name: selected!.name, size: 34),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected!.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (selected!.phone != null)
                      Text(
                        selected!.phone!,
                        style: TextStyle(
                            fontSize: 11, color: colors.textSecondary),
                      ),
                  ],
                ),
              ),
              Icon(Icons.swap_horiz_rounded,
                  size: 18, color: colors.primary),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openPicker(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: hasError
              ? colors.expenseBackground
              : colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: hasError ? colors.expense : colors.border,
            width: hasError ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.person_search_rounded,
                size: 18,
                color: hasError ? colors.expense : colors.textMuted),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                hasError ? 'Выберите клиента ↑' : 'Выберите клиента',
                style: TextStyle(
                  fontSize: 14,
                  color: hasError ? colors.expense : colors.textMuted,
                  fontWeight:
                      hasError ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  void _openPicker(BuildContext context) {
    final colors = context.appColors;
    showModalBottomSheet<Customer>(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (_) => _CustomerPickerSheet(
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
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final filtered = widget.customers
        .where((c) => c.name.toLowerCase().contains(_q.toLowerCase()))
        .toList();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.sm),
            child: Text(
              'Выберите клиента',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary),
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Поиск...',
                hintStyle: TextStyle(color: colors.textMuted),
                prefixIcon: Icon(Icons.search_rounded,
                    size: 18, color: colors.textMuted),
                filled: true,
                fillColor: colors.surfaceSecondary,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: colors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: colors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide:
                        BorderSide(color: colors.primary, width: 1.5)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.38),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
              children: filtered.map((c) {
                final sel = widget.selected?.id == c.id;
                return ListTile(
                  leading: AppAvatar(name: c.name, size: 38),
                  title: Text(c.name,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              sel ? FontWeight.w600 : FontWeight.w400,
                          color: colors.textPrimary)),
                  subtitle: c.phone != null
                      ? Text(c.phone!,
                          style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary))
                      : null,
                  trailing: sel
                      ? Icon(Icons.check_circle_rounded,
                          color: colors.primary, size: 20)
                      : null,
                  onTap: () => widget.onPick(c),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppRadius.md)),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
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

  static const _items = {
    OrderStatus.newOrder: (
      'Новый',
      Icons.fiber_new_rounded,
      Color(0xFF0F766E)
    ),
    OrderStatus.inProgress: (
      'В работе',
      Icons.play_circle_rounded,
      Color(0xFF14B8A6)
    ),
    OrderStatus.completed: (
      'Завершён',
      Icons.check_circle_rounded,
      Color(0xFF10B981)
    ),
    OrderStatus.cancelled: (
      'Отменён',
      Icons.cancel_rounded,
      Color(0xFF94A3B8)
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
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: sel
                  ? item.$3.withValues(alpha: 0.12)
                  : colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(
                  color: sel ? item.$3 : colors.border,
                  width: sel ? 1.5 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.$2,
                    size: 14,
                    color: sel ? item.$3 : colors.textMuted),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  item.$1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        sel ? FontWeight.w600 : FontWeight.w400,
                    color: sel ? item.$3 : colors.textSecondary,
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
