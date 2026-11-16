import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../components/app_avatar.dart';
import '../../components/app_modal_sheet.dart';
import '../../components/form_widgets.dart';
import '../../l10n/app_tr.dart';

// ─── Route wrapper ────────────────────────────────────────────────────────────

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, this.customerId});
  final String? customerId;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    await showAppModal<void>(
      context: context,
      child: _CustomerFormSheet(customerId: widget.customerId),
    );
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profile/customers');
      }
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _CustomerFormSheet extends StatefulWidget {
  const _CustomerFormSheet({this.customerId});
  final String? customerId;

  @override
  State<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<_CustomerFormSheet>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _loading = false;
  bool _isEdit = false;
  bool _dataLoading = false;
  Customer? _existing;

  late final AnimationController _stagger;

  void _populateFromCustomer(Customer c) {
    _existing = c;
    _nameCtrl.text = c.name;
    _phoneCtrl.text = c.phone ?? '';
    _emailCtrl.text = c.email ?? '';
    _notesCtrl.text = c.notes ?? '';
  }

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _nameCtrl.addListener(_onPreviewChange);
    _phoneCtrl.addListener(_onPreviewChange);

    if (widget.customerId != null) {
      _isEdit = true;
      final customerProvider = context.read<CustomerProvider>();
      final cached = customerProvider.allCustomers
          .where((c) => c.id == widget.customerId)
          .firstOrNull;

      if (cached != null) {
        // Populate synchronously before Frame 1!
        _populateFromCustomer(cached);
        _dataLoading = false;
        _stagger.forward();
      } else {
        // Show loading from Frame 1 (never empty inputs!)
        _dataLoading = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final c = await customerProvider.getById(widget.customerId!);
          if (!mounted) return;
          if (c != null) {
            setState(() {
              _populateFromCustomer(c);
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

  void _onPreviewChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onPreviewChange);
    _phoneCtrl.removeListener(_onPreviewChange);
    _stagger.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_isEdit && _existing != null) {
        await context.read<CustomerProvider>().update(
              _existing!.copyWith(
                name: _nameCtrl.text.trim(),
                phone: _phoneCtrl.text.trim().isNotEmpty
                    ? _phoneCtrl.text.trim()
                    : null,
                email: _emailCtrl.text.trim().isNotEmpty
                    ? _emailCtrl.text.trim()
                    : null,
                notes: _notesCtrl.text.trim().isNotEmpty
                    ? _notesCtrl.text.trim()
                    : null,
              ),
            );
      } else {
        await context.read<CustomerProvider>().add(
              Customer(
                id: const Uuid().v4(),
                name: _nameCtrl.text.trim(),
                phone: _phoneCtrl.text.trim().isNotEmpty
                    ? _phoneCtrl.text.trim()
                    : null,
                email: _emailCtrl.text.trim().isNotEmpty
                    ? _emailCtrl.text.trim()
                    : null,
                notes: _notesCtrl.text.trim().isNotEmpty
                    ? _notesCtrl.text.trim()
                    : null,
                createdAt: DateTime.now(),
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
    final previewName = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : context.tr('Новый клиент', 'New customer');
    final previewPhone = _phoneCtrl.text.trim().isNotEmpty
        ? _phoneCtrl.text.trim()
        : context.tr('Укажите контакты ниже', 'Enter contacts below');

    return AppModalSheet(
      title: _isEdit
          ? context.tr('Карточка клиента', 'Customer card')
          : context.tr('Новый клиент', 'New customer'),
      subtitle: _isEdit
          ? context.tr('Имя и контакты обновятся во всех связанных заказах',
              'Name and contacts will update across all linked orders')
          : context.tr('Добавьте клиента для быстрой привязки заказов',
              'Add a customer to quickly link orders'),
      headerIcon: Icons.person_add_alt_1_rounded,
      headerColor: colors.primary,
      bottomBar: _dataLoading
          ? null
          : FormSubmitButton(
              label: _isEdit
                  ? context.tr('Сохранить изменения', 'Save changes')
                  : context.tr('Добавить в базу', 'Add customer'),
              accentColor: colors.primary,
              isLoading: _loading,
              onPressed: _save,
              icon:
                  _isEdit ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
            ),
      body: _dataLoading
          ? SizedBox(
              height: 240,
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
            // Live identity preview card
            FormStaggerItem(
              animation: _stagger,
              index: 0,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    AppAvatar(name: previewName, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            previewName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            previewPhone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        context.tr('Клиент', 'Customer'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 1. Name
            FormStaggerItem(
              animation: _stagger,
              index: 1,
              child: SheetField(
                label: context.tr('ИМЯ ИЛИ КОМПАНИЯ', 'NAME OR COMPANY'),
                required: true,
                child: FormTextField(
                  controller: _nameCtrl,
                  prefixIcon: Icons.person_outline_rounded,
                  hint: context.tr(
                      'Например: Алишер Каримов', 'e.g., Alexey Ivanov'),
                  textCapitalization: TextCapitalization.words,
                  autofocus: !_isEdit,
                  textInputAction: TextInputAction.next,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? context.tr('Введите имя клиента', 'Enter customer name')
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Phone
            FormStaggerItem(
              animation: _stagger,
              index: 2,
              child: SheetField(
                label: context.tr('НОМЕР ТЕЛЕФОНА', 'PHONE NUMBER'),
                child: FormTextField(
                  controller: _phoneCtrl,
                  prefixIcon: Icons.phone_outlined,
                  hint: '+998 90 000 00 00',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Email
            FormStaggerItem(
              animation: _stagger,
              index: 3,
              child: SheetField(
                label: context.tr('EMAIL (НЕОБЯЗАТЕЛЬНО)', 'EMAIL (OPTIONAL)'),
                child: FormTextField(
                  controller: _emailCtrl,
                  prefixIcon: Icons.alternate_email_rounded,
                  hint: 'client@company.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!v.contains('@') || !v.contains('.')) {
                      return context.tr(
                          'Укажите корректный email', 'Enter a valid email');
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Notes
            FormStaggerItem(
              animation: _stagger,
              index: 4,
              child: SheetField(
                label: context.tr('ЗАМЕТКИ О КЛИЕНТЕ', 'CUSTOMER NOTES'),
                child: FormTextField(
                  controller: _notesCtrl,
                  prefixIcon: Icons.notes_rounded,
                  hint: context.tr('Предпочтения, адрес, реквизиты...',
                      'Preferences, address, details...'),
                  maxLines: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
