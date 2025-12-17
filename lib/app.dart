import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "core/prefs.dart";
import "core/theme/app_theme.dart"; // ✅ add this
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
        if (snap.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: themeMode,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: "Geofence Admin",
          themeMode: themeMode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: authed
              ? AppShell(
                  onLogout: () => setAuthed(ref, false),
                  themeMode: themeMode,
                  onThemeMode: (m) async => setThemeMode(ref, m),
                )
              : const LoginScreen(),
        );
      },
    );
  }
}
