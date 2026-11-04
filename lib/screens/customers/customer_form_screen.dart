import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../components/app_button.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, this.customerId});
  final String? customerId;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _loading = false;
  bool _isEdit = false;
  Customer? _existing;

  @override
  void initState() {
    super.initState();
    if (widget.customerId != null) {
      _isEdit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final c = await context
            .read<CustomerProvider>()
            .getById(widget.customerId!);
        if (c != null && mounted) {
          _existing = c;
          _nameCtrl.text = c.name;
          _phoneCtrl.text = c.phone ?? '';
          _emailCtrl.text = c.email ?? '';
          _notesCtrl.text = c.notes ?? '';
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
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
        final updated = _existing!.copyWith(
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
        );
        await context.read<CustomerProvider>().update(updated);
      } else {
        const uuid = Uuid();
        final customer = Customer(
          id: uuid.v4(),
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
        );
        await context.read<CustomerProvider>().add(customer);
      }
      HapticFeedback.mediumImpact();
      if (mounted) context.go('/profile/customers');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Редактировать клиента' : 'Новый клиент'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            _label(context, 'Имя клиента *'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _nameCtrl,
              style: TextStyle(color: colors.textPrimary),
              decoration: const InputDecoration(hintText: 'Иванов Иван'),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Обязательное поле' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'Телефон'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _phoneCtrl,
              style: TextStyle(color: colors.textPrimary),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: '+7 900 000-00-00'),
            ),
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'Email'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _emailCtrl,
              style: TextStyle(color: colors.textPrimary),
              keyboardType: TextInputType.emailAddress,
              decoration:
                  const InputDecoration(hintText: 'example@mail.ru'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (!v.contains('@') || !v.contains('.')) {
                  return 'Введите корректный email';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'Заметки'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              style: TextStyle(color: colors.textPrimary),
              decoration:
                  const InputDecoration(hintText: 'Дополнительная информация...'),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            AppButton(
              label: _isEdit ? 'Сохранить' : 'Добавить клиента',
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
