import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/household/household_screen.dart';
import '../features/household/household_session.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/transactions/transaction_form.dart';
import '../features/transactions/transaction_detail.dart';
import '../features/ledger/management_screen.dart';
import '../features/statistics/statistics_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/help/usage_guide_screen.dart';
import '../features/google_connection/google_connection_screen.dart';
import '../features/transactions/transaction_repository.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(path: state.uri.path, child: child),
      routes: [
        GoRoute(
            path: '/transaction/:id',
            builder: (context, state) => Consumer(
                builder: (context, ref, _) => TransactionDetail(
                    key: ObjectKey(ref.watch(transactionRepositoryProvider)),
                    id: state.pathParameters['id']!))),
        GoRoute(
            path: '/edit/:id',
            builder: (context, state) => Consumer(builder: (context, ref, _) {
                  final found = ref
                      .read(transactionsProvider)
                      .where((t) => t.id == state.pathParameters['id']);
                  return found.isEmpty
                      ? const Center(child: Text('거래를 찾을 수 없어요.'))
                      : TransactionForm(
                          key: ObjectKey(
                              ref.watch(transactionRepositoryProvider)),
                          initial: found.first);
                })),
        GoRoute(path: '/', builder: (context, state) => const CalendarScreen()),
        GoRoute(
            path: '/household',
            builder: (context, state) => const HouseholdScreen()),
        GoRoute(
            path: '/sign-in',
            builder: (context, state) => const SignInScreen()),
        GoRoute(
            path: '/statistics',
            builder: (context, state) => const StatisticsScreen()),
        GoRoute(
            path: '/add',
            builder: (context, state) => Consumer(
                builder: (context, ref, _) => TransactionForm(
                    key: ObjectKey(ref.watch(transactionRepositoryProvider))))),
        GoRoute(
            path: '/google-connection',
            builder: (context, state) => const GoogleConnectionScreen()),
        GoRoute(
            path: '/management',
            builder: (context, state) => Consumer(
                builder: (context, ref, _) => ManagementScreen(
                    key: ObjectKey(ref.watch(transactionRepositoryProvider))))),
        GoRoute(
            path: '/help',
            builder: (context, state) => const UsageGuideScreen()),
        GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen()),
      ],
    )
  ]);
  ref.onDispose(router.dispose);
  return router;
});

class PaylogApp extends ConsumerWidget {
  const PaylogApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(householdSessionProvider);
    return MaterialApp.router(
      title: 'paylog · 우리 집의 작은 기록',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.path, required this.child});
  final String path;
  final Widget child;
  static const paths = ['/', '/statistics', '/add', '/settings'];
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: SafeArea(
            bottom: false,
            child: Center(
                child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
                    child: Row(children: [
                      Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                              color: AppColors.dark,
                              borderRadius: BorderRadius.circular(11)),
                          child: const Icon(Icons.grid_view_rounded,
                              color: AppColors.highlight, size: 21)),
                      const SizedBox(width: 10),
                      const Expanded(
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text('paylog',
                                  style: TextStyle(
                                      fontSize: 23,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1)))),
                      const SizedBox(width: 12),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                              color: AppColors.accentSoft,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(
                              ref
                                  .watch(transactionRepositoryProvider)
                                  .storageLabel,
                              style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600))),
                    ])),
                Expanded(child: child),
              ]),
            ))),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                      decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: AppColors.border)),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: NavigationBar(
                            selectedIndex: const [
                              '/sign-in',
                              '/household',
                              '/google-connection',
                              '/help',
                              '/management'
                            ].contains(path)
                                ? 3
                                : paths.indexOf(path).clamp(0, 3),
                            onDestinationSelected: (index) =>
                                context.go(paths[index]),
                            destinations: const [
                              NavigationDestination(
                                  icon: Icon(Icons.calendar_today_outlined),
                                  selectedIcon: Icon(Icons.calendar_today),
                                  label: '달력'),
                              NavigationDestination(
                                  icon: Icon(Icons.donut_large_outlined),
                                  label: '통계'),
                              NavigationDestination(
                                  icon: Icon(Icons.add_circle_outline),
                                  selectedIcon: Icon(Icons.add_circle),
                                  label: '등록'),
                              NavigationDestination(
                                  icon: Icon(Icons.tune), label: '설정'),
                            ],
                          ))))),
        ),
      );
}
