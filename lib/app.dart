import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/auth/domain/auth_state.dart';
import 'core/auth/presentation/auth_controller.dart';
import 'core/auth/presentation/session_signing_out_page.dart';
import 'core/auth/presentation/session_startup_page.dart';
import 'core/auth/presentation/session_unavailable_page.dart';
import 'core/theme.dart';
import 'features/login_page.dart';
import 'features/home_page.dart';
import 'features/sports_page.dart';
import 'features/clubs_page.dart';
import 'features/committee_page.dart';
import 'features/profile_page.dart';
import 'features/detail_pages.dart';
import 'features/club_detail/club_detail_page.dart';
import 'features/athlete_detail/athlete_detail_page.dart';
import 'features/sport_detail/sport_detail_page.dart';
import 'features/attention_page.dart';
import 'features/search/global_search_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => refresh.value = next);
  final router = GoRouter(
    initialLocation: '/session',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      if (authState is AuthSigningOut) {
        return loc == '/signing-out' ? null : '/signing-out';
      }
      if (authState is AuthBootstrapping) {
        return loc == '/session' ? null : '/session';
      }
      if (authState is AuthTemporarilyUnavailable) {
        return loc == '/session-unavailable' ? null : '/session-unavailable';
      }
      if (authState is! AuthSignedIn) {
        return loc == '/login' ? null : '/login';
      }

      const authGates = {'/login', '/session', '/session-unavailable', '/signing-out'};
      if (authGates.contains(loc)) {
        return '/home';
      }
      return null;
    },
    errorBuilder: (context, state) => const MissingPage(),
    routes: [
      GoRoute(path: '/login', builder: (_, s) => const LoginPage()),
      GoRoute(
        path: '/session',
        builder: (_, _) => const SessionStartupPage(),
      ),
      GoRoute(
        path: '/signing-out',
        builder: (context, state) => const SessionSigningOutPage(),
      ),
      GoRoute(
        path: '/session-unavailable',
        builder: (context, state) {
          final authState = ref.read(authControllerProvider);
          final reason = (authState is AuthTemporarilyUnavailable)
              ? authState.reason
              : state.uri.queryParameters['reason'];
          return SessionUnavailablePage(reason: reason);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, s, shell) => _NavigationShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, s) => const HomePage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/sports', builder: (_, s) => const SportsPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/clubs', builder: (_, s) => const ClubsPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/committee',
                builder: (_, s) => const CommitteePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/profile', builder: (_, s) => const ProfilePage()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/sport/:name',
        builder: (_, s) => SportDetailPage(sport: s.pathParameters['name']!),
      ),
      GoRoute(
        path: '/club/:id',
        builder: (_, s) => ClubDetailPage(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/person/:id',
        builder: (_, s) => AthleteDetailPage(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/attention',
        builder: (_, s) => AttentionPage(type: s.uri.queryParameters['type']),
      ),
      GoRoute(
        path: '/search',
        builder: (_, _) => const GlobalSearchPage(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class KokApp extends ConsumerWidget {
  const KokApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'KOK · KONI Garut',
    debugShowCheckedModeBanner: false,
    theme: kokTheme(),
    routerConfig: ref.watch(routerProvider),
    builder: (context, child) => ColoredBox(
      color: const Color(0xFFE5EAF3),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SafeArea(child: child!),
        ),
      ),
    ),
  );
}

class _NavigationShell extends StatelessWidget {
  const _NavigationShell({required this.shell});
  final StatefulNavigationShell shell;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: (i) =>
          shell.goBranch(i, initialLocation: i == shell.currentIndex),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view_rounded),
          label: 'Beranda',
        ),
        NavigationDestination(
          icon: Icon(Icons.emoji_events_outlined),
          selectedIcon: Icon(Icons.emoji_events),
          label: 'Cabor',
        ),
        NavigationDestination(
          icon: Icon(Icons.apartment_outlined),
          selectedIcon: Icon(Icons.apartment),
          label: 'Klub',
        ),
        NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups),
          label: 'Anggota',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
    ),
  );
}
