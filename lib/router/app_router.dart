import 'package:go_router/go_router.dart';

import '../screens/onboarding/onboarding_screen.dart';
import '../screens/shell/app_shell.dart';
import '../screens/home/home_screen.dart';
import '../screens/finance/finance_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/orders/order_detail_screen.dart';
import '../screens/orders/order_form_screen.dart';
import '../screens/customers/customers_screen.dart';
import '../screens/customers/customer_detail_screen.dart';
import '../screens/customers/customer_form_screen.dart';
import '../screens/debts/debts_screen.dart';
import '../screens/debts/debt_form_screen.dart';
import '../screens/debts/debt_detail_screen.dart';
import '../screens/finance/transaction_form_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/reports/report_detail_screen.dart';

class AppRouter {
  static GoRouter router(bool onboardingDone) => GoRouter(
        initialLocation: onboardingDone ? '/home' : '/onboarding',
        routes: [
          GoRoute(
            path: '/onboarding',
            builder: (_, __) => const OnboardingScreen(),
          ),
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => const HomeScreen(),
              ),
              GoRoute(
                path: '/finance',
                builder: (_, __) => const FinanceScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (_, __) => const TransactionFormScreen(),
                  ),
                  GoRoute(
                    path: 'edit/:id',
                    builder: (_, state) => TransactionFormScreen(
                      transactionId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/orders',
                builder: (_, __) => const OrdersScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (_, __) => const OrderFormScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => OrderDetailScreen(
                      orderId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (_, state) => OrderFormScreen(
                          orderId: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: '/profile',
                builder: (_, __) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'customers',
                    builder: (_, __) => const CustomersScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (_, __) => const CustomerFormScreen(),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (_, state) => CustomerDetailScreen(
                          customerId: state.pathParameters['id']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            builder: (_, state) => CustomerFormScreen(
                              customerId: state.pathParameters['id'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'debts',
                    builder: (_, __) => const DebtsScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (_, __) => const DebtFormScreen(),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (_, state) => DebtDetailScreen(
                          debtId: state.pathParameters['id']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            builder: (_, state) => DebtFormScreen(
                              debtId: state.pathParameters['id'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (_, __) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: 'reports',
                    builder: (_, __) => const ReportsScreen(),
                    routes: [
                      GoRoute(
                        path: ':year/:month',
                        builder: (_, state) => ReportDetailScreen(
                          year: int.parse(state.pathParameters['year']!),
                          month: int.parse(state.pathParameters['month']!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
}
