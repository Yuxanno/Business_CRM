import 'package:go_router/go_router.dart';

import '../screens/onboarding/onboarding_screen.dart';
import '../screens/shell/app_shell.dart';
import '../screens/home/home_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
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
import '../models/transaction.dart';
import '../screens/finance/transaction_form_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/profile_detail_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/reports/report_detail_screen.dart';

class AppRouter {
  static GoRouter router(bool onboardingDone) => GoRouter(
        initialLocation: onboardingDone ? '/home' : '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (ctx, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/register',
            builder: (ctx, state) => const RegisterScreen(),
          ),
          GoRoute(
            path: '/onboarding',
            builder: (ctx, state) => const OnboardingScreen(),
          ),
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/home',
                builder: (ctx, state) => const HomeScreen(),
              ),
              GoRoute(
                path: '/finance',
                builder: (ctx, state) => const FinanceScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (ctx, state) {
                      final type = state.uri.queryParameters['type'];
                      return TransactionFormScreen(
                        initialType: type == 'expense'
                            ? TransactionType.expense
                            : type == 'income'
                                ? TransactionType.income
                                : null,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'edit/:id',
                    builder: (ctx, state) => TransactionFormScreen(
                      transactionId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/orders',
                builder: (ctx, state) => const OrdersScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (ctx, state) => const OrderFormScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (ctx, state) => OrderDetailScreen(
                      orderId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (ctx, state) => OrderFormScreen(
                          orderId: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: '/profile',
                builder: (ctx, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'customers',
                    builder: (ctx, state) => const CustomersScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (ctx, state) => const CustomerFormScreen(),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (ctx, state) => CustomerDetailScreen(
                          customerId: state.pathParameters['id']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            builder: (ctx, state) => CustomerFormScreen(
                              customerId: state.pathParameters['id'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'debts',
                    builder: (ctx, state) => const DebtsScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (ctx, state) => const DebtFormScreen(),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (ctx, state) => DebtDetailScreen(
                          debtId: state.pathParameters['id']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            builder: (ctx, state) => DebtFormScreen(
                              debtId: state.pathParameters['id'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (ctx, state) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: 'details',
                    builder: (ctx, state) => const ProfileDetailScreen(),
                  ),
                  GoRoute(
                    path: 'reports',
                    builder: (ctx, state) => const ReportsScreen(),
                    routes: [
                      GoRoute(
                        path: ':year/:month',
                        builder: (ctx, state) => ReportDetailScreen(
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
