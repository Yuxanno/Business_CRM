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

/// Regular screen route with a short (150 ms) fade instead of the default
/// 300 ms Material transition, so taps feel instant.
GoRoute _fastRoute({
  required String path,
  required Widget Function(BuildContext, GoRouterState) builder,
  List<RouteBase> routes = const <RouteBase>[],
}) {
  return GoRoute(
    path: path,
    routes: routes,
    pageBuilder: (ctx, state) => CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      child: builder(ctx, state),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    ),
  );
}

class AppRouter {
  static GoRouter router({String initialLocation = '/home'}) => GoRouter(
        initialLocation: initialLocation,
        routes: [
          _fastRoute(
            path: '/login',
            builder: (ctx, state) => const LoginScreen(),
          ),
          _fastRoute(
            path: '/register',
            builder: (ctx, state) => const LoginScreen(initialRegister: true),
          ),
          _fastRoute(
            path: '/onboarding',
            builder: (ctx, state) => const OnboardingScreen(),
          ),
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) =>
                AppShell(navigationShell: navigationShell),
            branches: [
              StatefulShellBranch(
                routes: [
                  _fastRoute(
                    path: '/home',
                    builder: (ctx, state) => const HomeScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  _fastRoute(
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
                  _fastRoute(
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
                      _fastRoute(
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
                  _fastRoute(
                    path: '/profile',
                    builder: (ctx, state) => const ProfileScreen(),
                    routes: [
                      _fastRoute(
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
                          _fastRoute(
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
                      _fastRoute(
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
                          _fastRoute(
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
                      _fastRoute(
                        path: 'settings',
                        builder: (ctx, state) => const SettingsScreen(),
                      ),
                      _fastRoute(
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
                      _fastRoute(
                        path: 'details',
                        builder: (ctx, state) => const ProfileDetailScreen(),
                      ),
                      _fastRoute(
                        path: 'reports',
                        builder: (ctx, state) => const ReportsScreen(),
                        routes: [
                          _fastRoute(
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
