import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "core/prefs.dart";
import "core/theme/app_theme.dart";
import "features/auth/login_screen.dart";
import "features/shell/app_shell.dart";

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
                          // ignore: discarded_futures
                          logout(ref);
                        },
                        themeMode: themeMode,
                        onThemeMode: (m) async => setThemeMode(ref, m),
                      )
                    : const LoginScreen()),
        );
      },
    );
  }
}
