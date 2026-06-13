import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/instances/presentation/instances_screen.dart';
import '../features/auth/presentation/accounts_screen.dart';
import '../features/instances/presentation/instance_detail_screen.dart';
import '../features/mods/presentation/modpacks_screen.dart';
import '../features/console/presentation/console_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'shell_screen.dart';

// ShellRoute creates persistent navigation panel while routes change inner content
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ShellScreen(child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (ctx, state) => _slideUpPage(
            key: state.pageKey,
            child: const HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/instances',
          pageBuilder: (ctx, state) => _slideUpPage(
            key: state.pageKey,
            child: const InstancesScreen(),
          ),
        ),
        GoRoute(
          path: '/accounts',
          pageBuilder: (ctx, state) => _slideUpPage(
            key: state.pageKey,
            child: const AccountsScreen(),
          ),
        ),
        GoRoute(
          path: '/instances/:id',
          pageBuilder: (ctx, state) => _slideUpPage(
            key: state.pageKey,
            child: InstanceDetailScreen(id: state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/modpacks',
          pageBuilder: (ctx, state) => _slideUpPage(
            key: state.pageKey,
            child: const ModpacksScreen(),
          ),
        ),
        GoRoute(
          path: '/console',
          pageBuilder: (ctx, state) => _slideUpPage(
            key: state.pageKey,
            child: const ConsoleScreen(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (ctx, state) => _slideUpPage(
            key: state.pageKey,
            child: const SettingsScreen(),
          ),
        ),
      ],
    ),
  ],
);

CustomTransitionPage<void> _slideUpPage({
  required LocalKey key,
  required Widget child,
}) {
  // Fade+slide animation for screen transitions
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(

        opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOut),
        ),
        child: FadeTransition(

          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.05), 
              end: Offset.zero,
            ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutQuad)),
            child: child,
          ),
        ),
      );
    },
  );
}
