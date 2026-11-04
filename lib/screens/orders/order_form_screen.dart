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
import '../../components/app_button.dart';

class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key, this.orderId});
  final String? orderId;

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
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
  Order? _existingOrder;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<CustomerProvider>().load();
      if (widget.orderId != null) {
        _isEdit = true;
        final order =
            await context.read<OrderProvider>().getById(widget.orderId!);
        if (order != null && mounted) {
          _existingOrder = order;
          _titleCtrl.text = order.title;
          _priceCtrl.text =
              (order.totalPriceCents / 100).toStringAsFixed(2);
          _descCtrl.text = order.description ?? '';
          _notesCtrl.text = order.notes ?? '';
          _dueDate = order.dueDate;
          _status = order.status;
          final customer = await context
              .read<CustomerProvider>()
              .getById(order.customerId);
          if (mounted) setState(() => _selectedCustomer = customer);
        }
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите клиента')),
      );
      return;
    }

    final price =
        FinancialCalculator.parseAmountToCents(_priceCtrl.text);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректную сумму')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      if (_isEdit && _existingOrder != null) {
        final updated = _existingOrder!.copyWith(
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
        );
        await context.read<OrderProvider>().update(updated);
      } else {
        const uuid = Uuid();
        final order = Order(
          id: uuid.v4(),
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
        );
        await context.read<OrderProvider>().add(order);
      }
      HapticFeedback.mediumImpact();
      if (mounted) context.go('/orders');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final customers = context.watch<CustomerProvider>().customers;
    final currency = context.watch<SettingsProvider>().currency;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Редактировать заказ' : 'Новый заказ'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            _label(context, 'Название заказа *'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _titleCtrl,
              style: TextStyle(color: colors.textPrimary),
              decoration: const InputDecoration(
                  hintText: 'Например: Разработка логотипа'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Обязательное поле' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'Клиент *'),
            const SizedBox(height: AppSpacing.xs),
            _CustomerDropdown(
              customers: customers,
              selected: _selectedCustomer,
              onChanged: (c) => setState(() => _selectedCustomer = c),
              onAddNew: () async {
                await context.push('/profile/customers/new');
                await context.read<CustomerProvider>().load();
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'Стоимость ($currency) *'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              style: TextStyle(color: colors.textPrimary),
              decoration: const InputDecoration(hintText: '0.00'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Обязательное поле';
                final cents =
                    FinancialCalculator.parseAmountToCents(v);
                if (cents == null || cents <= 0) {
                  return 'Введите корректную сумму';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'Описание'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              style: TextStyle(color: colors.textPrimary),
              decoration:
                  const InputDecoration(hintText: 'Описание работы...'),
            ),
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'Дедлайн'),
            const SizedBox(height: AppSpacing.xs),
            _DatePicker(
              value: _dueDate,
              onChanged: (d) => setState(() => _dueDate = d),
            ),
            if (_isEdit) ...[
              const SizedBox(height: AppSpacing.lg),
              _label(context, 'Статус'),
              const SizedBox(height: AppSpacing.xs),
              _StatusDropdown(
                value: _status,
                onChanged: (s) => setState(() => _status = s),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'Заметки'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              style: TextStyle(color: colors.textPrimary),
              decoration:
                  const InputDecoration(hintText: 'Внутренние заметки...'),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            AppButton(
              label: _isEdit ? 'Сохранить' : 'Создать заказ',
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

class _CustomerDropdown extends StatelessWidget {
  const _CustomerDropdown({
    required this.customers,
    required this.selected,
    required this.onChanged,
    required this.onAddNew,
  });

  final List<Customer> customers;
  final Customer? selected;
  final ValueChanged<Customer?> onChanged;
  final VoidCallback onAddNew;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Customer>(
          value: selected,
          isExpanded: true,
          hint: Text('Выберите клиента',
              style: TextStyle(color: colors.textMuted, fontSize: 14)),
          dropdownColor: colors.surface,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
          onChanged: onChanged,
          items: [
            ...customers.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c.name),
                )),
            DropdownMenuItem(
              value: null,
              enabled: false,
              child: TextButton.icon(
                onPressed: onAddNew,
                icon: Icon(Icons.add_rounded,
                    size: 16, color: colors.primary),
                label: Text('Добавить клиента',
                    style:
                        TextStyle(fontSize: 13, color: colors.primary)),
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
          initialDate: value ?? DateTime.now().add(const Duration(days: 7)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme:
                  Theme.of(ctx).colorScheme.copyWith(primary: colors.primary),
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
                    : 'Выберите дату',
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
                child:
                    Icon(Icons.close_rounded, size: 16, color: colors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({required this.value, required this.onChanged});
  final OrderStatus value;
  final ValueChanged<OrderStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final labels = {
      OrderStatus.newOrder: 'Новый',
      OrderStatus.inProgress: 'В работе',
      OrderStatus.completed: 'Завершён',
      OrderStatus.cancelled: 'Отменён',
    };

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<OrderStatus>(
          value: value,
          isExpanded: true,
          dropdownColor: colors.surface,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
          onChanged: (s) => s != null ? onChanged(s) : null,
          items: OrderStatus.values
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(labels[s]!),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
