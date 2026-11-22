import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/transaction.dart';
import '../../providers/settings_provider.dart';
import '../../components/app_card.dart';
import '../../components/app_modal_sheet.dart';
import '../../components/form_widgets.dart';
import '../../l10n/app_tr.dart';

const double _kPagePadding = 20.0;

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, this.initialType});

  final TransactionType? initialType;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late TransactionType _selectedType;
  final _newCategoryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? TransactionType.income;
  }

  @override
  void dispose() {
    _newCategoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final text = _newCategoryCtrl.text.trim();
    if (text.isEmpty) {
      await _showAddCategorySheet();
      return;
    }
    HapticFeedback.mediumImpact();
    await context.read<SettingsProvider>().addCategory(_selectedType, text);
    _newCategoryCtrl.clear();
    if (mounted) {
      FocusScope.of(context).unfocus();
      setState(() {});
    }
  }

  Future<void> _showAddCategorySheet() async {
    final ctrl = TextEditingController();
    final colors = context.appColors;
    final isIncome = _selectedType == TransactionType.income;

    await showAppModal<void>(
      context: context,
      child: Builder(
        builder: (sheetCtx) {
          return AppModalSheet(
            title: context.tr('Новая категория', 'New category'),
            subtitle: isIncome
                ? context.tr('Добавление в «Доходы»', 'Adding to Income')
                : context.tr('Добавление в «Расходы»', 'Adding to Expenses'),
            headerIcon: Icons.add_circle_outline_rounded,
            headerColor: colors.primary,
            bottomBar: FormSubmitButton(
              label: context.tr('Добавить категорию', 'Add category'),
              icon: Icons.add_rounded,
              accentColor: colors.primary,
              isLoading: false,
              onPressed: () async {
                final text = ctrl.text.trim();
                if (text.isEmpty) return;
                await context
                    .read<SettingsProvider>()
                    .addCategory(_selectedType, text);
                if (sheetCtx.mounted) {
                  Navigator.of(sheetCtx).pop();
                }
                if (mounted) setState(() {});
              },
            ),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: SheetField(
                label: context.tr('НАЗВАНИЕ КАТЕГОРИИ', 'CATEGORY NAME'),
                required: true,
                child: FormTextField(
                  controller: ctrl,
                  prefixIcon: Icons.label_outline_rounded,
                  hint: isIncome
                      ? context.tr('Например: Консультация, Доставка...',
                          'e.g., Consulting, Delivery...')
                      : context.tr('Например: Упаковка, Налоги...',
                          'e.g., Packaging, Taxes...'),
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                  onFieldSubmitted: (val) async {
                    final text = val.trim();
                    if (text.isEmpty) return;
                    await context
                        .read<SettingsProvider>()
                        .addCategory(_selectedType, text);
                    if (sheetCtx.mounted) {
                      Navigator.of(sheetCtx).pop();
                    }
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showRenameSheet(String catKey, String currentLabel) async {
    final ctrl = TextEditingController(text: currentLabel);
    final colors = context.appColors;

    await showAppModal<void>(
      context: context,
      child: Builder(
        builder: (sheetCtx) {
          return AppModalSheet(
            title: context.tr('Изменить категорию', 'Edit category'),
            subtitle: _selectedType == TransactionType.income
                ? context.tr('Категория дохода', 'Income category')
                : context.tr('Категория расхода', 'Expense category'),
            headerIcon: _iconFor(catKey),
            headerColor: colors.primary,
            bottomBar: FormSubmitButton(
              label: context.tr('Сохранить название', 'Save name'),
              icon: Icons.check_rounded,
              accentColor: colors.primary,
              isLoading: false,
              onPressed: () async {
                final text = ctrl.text.trim();
                if (text.isEmpty) return;
                await context
                    .read<SettingsProvider>()
                    .renameCategory(_selectedType, catKey, text);
                if (sheetCtx.mounted) {
                  Navigator.of(sheetCtx).pop();
                }
              },
            ),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: SheetField(
                label: context.tr('НАЗВАНИЕ КАТЕГОРИИ', 'CATEGORY NAME'),
                required: true,
                child: FormTextField(
                  controller: ctrl,
                  prefixIcon: _iconFor(catKey),
                  hint: context.tr(
                      'Введите новое название...', 'Enter new name...'),
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                  onFieldSubmitted: (val) async {
                    final text = val.trim();
                    if (text.isEmpty) return;
                    await context
                        .read<SettingsProvider>()
                        .renameCategory(_selectedType, catKey, text);
                    if (sheetCtx.mounted) {
                      Navigator.of(sheetCtx).pop();
                    }
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _iconFor(String cat) {
    return switch (cat) {
      'order_payment' => Icons.shopping_bag_outlined,
      'service' => Icons.handyman_outlined,
      'sale' => Icons.storefront_outlined,
      'refund_received' => Icons.replay_rounded,
      'other_income' => Icons.more_horiz_rounded,
      'supplies' => Icons.inventory_2_outlined,
      'rent' => Icons.home_work_outlined,
      'utilities' => Icons.bolt_rounded,
      'transport' => Icons.local_shipping_outlined,
      'marketing' => Icons.campaign_outlined,
      'salary' => Icons.badge_outlined,
      'equipment' => Icons.precision_manufacturing_outlined,
      'other_expense' => Icons.more_horiz_rounded,
      _ => Icons.label_outline_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final settings = context.watch<SettingsProvider>();
    final isIncome = _selectedType == TransactionType.income;
    final categories =
        isIncome ? settings.incomeCategories : settings.expenseCategories;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Top Bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kPagePadding,
                AppSpacing.md,
                _kPagePadding,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/profile');
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('Категории', 'Categories'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  if (settings.hasHiddenDefaultCategories)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        settings.restoreDefaultCategories();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          context.tr(
                              'Вернуть стандартные', 'Restore defaults'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── 2. Type Switcher (Доходы / Расходы) ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _kPagePadding,
                vertical: AppSpacing.xs,
              ),
              child: Container(
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: colors.border),
                ),
                child: Stack(
                  children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      alignment: isIncome
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: FractionallySizedBox(
                        widthFactor: 0.5,
                        heightFactor: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(
                                () => _selectedType = TransactionType.income,
                              );
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isIncome
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: isIncome
                                      ? Colors.white
                                      : colors.textSecondary,
                                ),
                                child: Text(
                                  context.tr(
                                      'Доходы (${settings.incomeCategories.length})',
                                      'Income (${settings.incomeCategories.length})'),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(
                                () => _selectedType = TransactionType.expense,
                              );
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: !isIncome
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: !isIncome
                                      ? Colors.white
                                      : colors.textSecondary,
                                ),
                                child: Text(
                                  context.tr(
                                      'Расходы (${settings.expenseCategories.length})',
                                      'Expenses (${settings.expenseCategories.length})'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── 3. Quick Add Bar ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kPagePadding),
              child: Row(
                children: [
                  Expanded(
                    child: FormTextField(
                      controller: _newCategoryCtrl,
                      prefixIcon: Icons.add_circle_outline_rounded,
                      hint: isIncome
                          ? context.tr('Новая категория дохода...',
                              'New income category...')
                          : context.tr('Новая категория расхода...',
                              'New expense category...'),
                      textCapitalization: TextCapitalization.sentences,
                      onFieldSubmitted: (_) => _addCategory(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _addCategory,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        context.tr('Добавить', 'Add'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── 4. Categories List ─────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    ...previousChildren,
                    ?currentChild,
                  ],
                ),
                child: ListView.separated(
                  key: ValueKey(_selectedType),
                  physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  _kPagePadding,
                  2,
                  _kPagePadding,
                  80,
                ),
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final catKey = categories[i];
                  final label = TransactionCategories.labelFor(catKey);
                  final isDefault =
                      TransactionCategories.defaultLabels.containsKey(catKey);

                  return AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.border),
                          ),
                          child: Icon(
                            _iconFor(catKey),
                            size: 17,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              Text(
                                isDefault
                                    ? context.tr('Стандартная категория',
                                        'Default category')
                                    : context.tr('Пользовательская категория',
                                        'Custom category'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Edit button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _showRenameSheet(catKey, label);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: colors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.border),
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 15,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Delete button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            settings.removeCategory(_selectedType, catKey);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: colors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.border),
                            ),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: colors.expense,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

