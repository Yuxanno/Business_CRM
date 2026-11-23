import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/onboarding/onboarding_screen.dart';
import '../screens/shell/app_shell.dart';
import '../screens/home/home_screen.dart';
import '../screens/auth/login_screen.dart';
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
import '../models/debt.dart';
import '../models/transaction.dart';
import '../screens/finance/transaction_form_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/profile_detail_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/categories_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/reports/report_detail_screen.dart';

/// Builds a non-opaque page so the screen underneath remains visible
/// behind modal bottom sheets.
CustomTransitionPage<void> _modalPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    opaque: false,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    child: child,
    transitionsBuilder: (_, _, _, child) => child,
  );
}

class AppRouter {
  static GoRouter router({String initialLocation = '/home'}) => GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: '/login',
            builder: (ctx, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/register',
            builder: (ctx, state) => const LoginScreen(initialRegister: true),
          ),
          GoRoute(
            path: '/onboarding',
            builder: (ctx, state) => const OnboardingScreen(),
          ),
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) =>
                AppShell(navigationShell: navigationShell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/home',
                    builder: (ctx, state) => const HomeScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/finance',
                    builder: (ctx, state) => const FinanceScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        pageBuilder: (ctx, state) {
                          final type = state.uri.queryParameters['type'];
                          return _modalPage(
                            state,
                            TransactionFormScreen(
                              initialType: type == 'expense'
                                  ? TransactionType.expense
                                  : type == 'income'
                                      ? TransactionType.income
                                      : null,
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'edit/:id',
                        pageBuilder: (ctx, state) => _modalPage(
                          state,
                          TransactionFormScreen(
                            transactionId: state.pathParameters['id'],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/orders',
                    builder: (ctx, state) => const OrdersScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        pageBuilder: (ctx, state) => _modalPage(
                          state,
                          const OrderFormScreen(),
                        ),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (ctx, state) => OrderDetailScreen(
                          orderId: state.pathParameters['id']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            pageBuilder: (ctx, state) => _modalPage(
                              state,
                              OrderFormScreen(
                                orderId: state.pathParameters['id'],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
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
                            pageBuilder: (ctx, state) => _modalPage(
                              state,
                              const CustomerFormScreen(),
                            ),
                          ),
                          GoRoute(
                            path: ':id',
                            builder: (ctx, state) => CustomerDetailScreen(
                              customerId: state.pathParameters['id']!,
                            ),
                            routes: [
                              GoRoute(
                                path: 'edit',
                                pageBuilder: (ctx, state) => _modalPage(
                                  state,
                                  CustomerFormScreen(
                                    customerId: state.pathParameters['id'],
                                  ),
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
                            pageBuilder: (ctx, state) {
                              final dir = state.uri.queryParameters['direction'];
                              return _modalPage(
                                state,
                                DebtFormScreen(
                                  initialDirection: dir == 'payable'
                                      ? DebtDirection.payable
                                      : dir == 'receivable'
                                          ? DebtDirection.receivable
                                          : null,
                                ),
                              );
                            },
                          ),
                          GoRoute(
                            path: ':id',
                            builder: (ctx, state) => DebtDetailScreen(
                              debtId: state.pathParameters['id']!,
                            ),
                            routes: [
                              GoRoute(
                                path: 'edit',
                                pageBuilder: (ctx, state) => _modalPage(
                                  state,
                                  DebtFormScreen(
                                    debtId: state.pathParameters['id'],
                                  ),
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
                        path: 'categories',
                        builder: (ctx, state) {
                          final type = state.uri.queryParameters['type'];
                          return CategoriesScreen(
                            initialType: type == 'expense'
                                ? TransactionType.expense
                                : TransactionType.income,
                          );
                        },
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
          ),
        ],
      );
}
