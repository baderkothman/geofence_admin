import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "core/prefs.dart";
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
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: "Geofence Admin",
          themeMode: themeMode,
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          home: authed
              ? AppShell(
                  onLogout: () => setAuthed(ref, false),
                  themeMode: themeMode,
                  onThemeMode: (m) async {
                    await setThemeMode(ref, m);
                  },
                )
              : const LoginScreen(),
        );
      },
    );
  }

  ThemeData _lightTheme() {
    final cs = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2CB7B1),
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: const Color(0xFFF7F7F5),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  ThemeData _darkTheme() {
    final cs = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2CB7B1),
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: const Color(0xFF071226),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
