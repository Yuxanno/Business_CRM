import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_card.dart';
import '../../components/app_avatar.dart';
import '../../components/app_search_bar.dart';
import '../../components/app_empty_state.dart';
import '../../components/app_confirm_sheet.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final provider = context.watch<CustomerProvider>();
    final currency = context.watch<SettingsProvider>().currency;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Клиенты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            onPressed: () => context.go('/profile/customers/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
            child: AppSearchBar(
              hint: 'Поиск по имени или телефону...',
              controller: _searchCtrl,
              onChanged: provider.setSearch,
              onClear: () {
                _searchCtrl.clear();
                provider.setSearch('');
              },
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? Center(
                    child:
                        CircularProgressIndicator(color: colors.primary))
                : provider.customers.isEmpty
                    ? AppEmptyState(
                        icon: Icons.people_outline_rounded,
                        title: 'Клиентов нет',
                        subtitle: 'Нажмите + чтобы добавить первого клиента',
                        actionLabel: 'Добавить клиента',
                        onAction: () =>
                            context.go('/profile/customers/new'),
                      )
                    : RefreshIndicator(
                        color: colors.primary,
                        onRefresh: () =>
                            context.read<CustomerProvider>().load(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 80),
                          itemCount: provider.customers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (_, i) {
                            final customer = provider.customers[i];
                            return _CustomerCard(
                              customer: customer,
                              currency: currency,
                              onTap: () => context
                                  .go('/profile/customers/${customer.id}'),
                              onEdit: () => context.go(
                                  '/profile/customers/${customer.id}/edit'),
                              onDelete: () =>
                                  _confirmDelete(context, customer),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, Customer customer) async {
    final confirm = await showConfirmSheet(
      context: context,
      title: 'Удалить клиента?',
      message:
          'История заказов клиента будет сохранена, но привязка к клиенту пропадёт.',
    );
    if (confirm == true && mounted) {
      await context.read<CustomerProvider>().delete(customer.id);
    }
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.currency,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Customer customer;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Slidable(
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            icon: Icons.edit_rounded,
            label: 'Изменить',
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: colors.expense,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: 'Удалить',
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ],
      ),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        onTap: onTap,
        child: Row(
          children: [
            AppAvatar(name: customer.name, size: 46),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (customer.phone != null)
                    Text(
                      customer.phone!,
                      style: TextStyle(
                          fontSize: 12, color: colors.textSecondary),
                    )
                  else
                    Text(
                      'Добавлен ${DateHelper.formatDate(customer.createdAt)}',
                      style: TextStyle(
                          fontSize: 12, color: colors.textMuted),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${customer.totalOrdersCount} зак.',
                  style: TextStyle(
                      fontSize: 12, color: colors.textMuted),
                ),
                if (customer.outstandingBalanceCents > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    FinancialCalculator.formatCentsCompact(
                        customer.outstandingBalanceCents,
                        currency: currency),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.warning,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
