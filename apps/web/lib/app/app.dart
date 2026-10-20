import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/transactions/transaction_form.dart';
import '../features/statistics/statistics_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/google_connection/google_connection_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(path: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const CalendarScreen()),
        GoRoute(
            path: '/statistics',
            builder: (context, state) => const StatisticsScreen()),
        GoRoute(
            path: '/add', builder: (context, state) => const TransactionForm()),
        GoRoute(
            path: '/google-connection',
            builder: (context, state) => const GoogleConnectionScreen()),
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
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'paylog · 우리 집의 작은 기록',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: ref.watch(routerProvider),
      );
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.path, required this.child});
  final String path;
  final Widget child;
  static const paths = ['/', '/statistics', '/add', '/settings'];
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            bottom: false,
            child: Center(
                child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: Row(children: [
                      Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                              color: AppColors.teal,
                              borderRadius: BorderRadius.circular(11)),
                          child: const Icon(Icons.grid_view_rounded,
                              color: Colors.white, size: 21)),
                      const SizedBox(width: 10),
                      const Expanded(
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text('paylog',
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1)))),
                      const SizedBox(width: 12),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                              color: AppColors.tealSoft,
                              borderRadius: BorderRadius.circular(20)),
                          child: const Text('샘플 가계부',
                              style: TextStyle(
                                  color: AppColors.teal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600))),
                    ])),
                Expanded(child: child),
              ]),
            ))),
        bottomNavigationBar: NavigationBar(
          selectedIndex: path == '/google-connection'
              ? 3
              : paths.indexOf(path).clamp(0, 3),
          onDestinationSelected: (index) => context.go(paths[index]),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today),
                label: '달력'),
            NavigationDestination(
                icon: Icon(Icons.donut_large_outlined), label: '통계'),
            NavigationDestination(
                icon: Icon(Icons.add_circle_outline),
                selectedIcon: Icon(Icons.add_circle),
                label: '등록'),
            NavigationDestination(icon: Icon(Icons.tune), label: '설정'),
          ],
        ),
      );
}
