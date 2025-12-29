// D:\geofence_project\geofence_admin\lib\app.dart

import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "core/prefs.dart";
import "core/theme/app_theme.dart";
import "features/auth/login_screen.dart";
import "features/shell/app_shell.dart";

/// Root widget of the Geofence Admin Flutter application.
///
/// Responsibilities:
/// - Wait for bootstrap initialization (SharedPreferences + persisted state).
/// - Apply theme mode (light/dark).
/// - Route to login or the main shell based on auth state.
class GeofenceAdminApp extends ConsumerWidget {
  const GeofenceAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(bootstrapProvider);
    final themeMode = ref.watch(themeModeProvider);
    final authed = ref.watch(authProvider);

    return FutureBuilder(
      future: boot,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: "Geofence Admin",
          themeMode: themeMode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: loading
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : (authed
                    ? AppShell(
                        onLogout: () {
                          // `logout` is async; we intentionally fire-and-forget from a sync callback.
                          unawaited(logout(ref));
                        },
                        themeMode: themeMode,
                        onThemeMode: (m) => setThemeMode(ref, m),
                      )
                    : const LoginScreen()),
        );
      },
    );
  }
}
