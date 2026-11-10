import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../components/app_modal_sheet.dart';
import '../../components/form_widgets.dart';

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
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: Colors.transparent);
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
  Customer? _existing;

  late AnimationController _stagger;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _stagger.forward();

    if (widget.customerId != null) {
      _isEdit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final c = await context
            .read<CustomerProvider>()
            .getById(widget.customerId!);
        if (c != null && mounted) {
          setState(() {
            _existing = c;
            _nameCtrl.text = c.name;
            _phoneCtrl.text = c.phone ?? '';
            _emailCtrl.text = c.email ?? '';
            _notesCtrl.text = c.notes ?? '';
          });
        }
      });
    }
  }

  @override
  void dispose() {
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

    return AppModalSheet(
      title: _isEdit ? 'Редактировать клиента' : 'Новый клиент',
      subtitle: _isEdit
          ? 'Имя и контакты обновятся в заказах этого клиента'
          : 'Имя нужно, чтобы привязать заказы и долги. Телефон можно добавить сразу.',
      headerIcon: Icons.person_add_rounded,
      headerColor: colors.primary,
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
            FormStaggerItem(
              animation: _stagger,
              index: 0,
              child: SheetField(
                label: 'ИМЯ КЛИЕНТА',
                required: true,
                child: FormTextField(
                  controller: _nameCtrl,
                  hint: 'Иванов Иван',
                  textCapitalization: TextCapitalization.words,
                  autofocus: !_isEdit,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Введите имя' : null,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            FormStaggerItem(
              animation: _stagger,
              index: 1,
              child: SheetField(
                label: 'ТЕЛЕФОН',
                child: FormTextField(
                  controller: _phoneCtrl,
                  hint: '+7 900 000-00-00',
                  keyboardType: TextInputType.phone,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            FormStaggerItem(
              animation: _stagger,
              index: 2,
              child: SheetField(
                label: 'EMAIL',
                child: FormTextField(
                  controller: _emailCtrl,
                  hint: 'example@mail.ru',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Некорректный email';
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            FormStaggerItem(
              animation: _stagger,
              index: 3,
              child: SheetField(
                label: 'ЗАМЕТКИ',
                child: FormTextField(
                  controller: _notesCtrl,
                  hint: 'Дополнительная информация...',
                  maxLines: 3,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            FormStaggerItem(
              animation: _stagger,
              index: 4,
              child: FormSubmitButton(
                label: _isEdit ? 'Сохранить' : 'Добавить клиента',
                accentColor: colors.primary,
                isLoading: _loading,
                onPressed: _save,
                icon: _isEdit ? Icons.check_rounded : Icons.person_add_rounded,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
