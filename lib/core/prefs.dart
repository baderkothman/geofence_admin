import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

const _kAuth = "adminAuth";
const _kTheme = "adminTheme"; // light/dark only

/// This MUST be overridden in main.dart
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError("sharedPrefsProvider must be overridden in main()");
});

final authProvider = StateProvider<bool>((ref) => false);

// ✅ default = dark (no system)
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

/// App bootstrap (loads auth + theme once)
final bootstrapProvider = Provider<Future<void>>((ref) async {
  final p = ref.read(sharedPrefsProvider);

  // auth
  final authed = p.getBool(_kAuth) ?? false;
  ref.read(authProvider.notifier).state = authed;

  // theme (light/dark only)
  final t = p.getString(_kTheme) ?? "dark";
  ref.read(themeModeProvider.notifier).state = (t == "light")
      ? ThemeMode.light
      : ThemeMode.dark;
});

Future<void> setAuthed(WidgetRef ref, bool v) async {
  final p = ref.read(sharedPrefsProvider);
  await p.setBool(_kAuth, v);
  ref.read(authProvider.notifier).state = v;
}

// ✅ Toggle only: light <-> dark
Future<void> toggleTheme(WidgetRef ref) async {
  final p = ref.read(sharedPrefsProvider);
  final current = ref.read(themeModeProvider);

  final next = current == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  ref.read(themeModeProvider.notifier).state = next;

  await p.setString(_kTheme, next == ThemeMode.light ? "light" : "dark");
}

// ✅ Set only light/dark (no system)
Future<void> setThemeMode(WidgetRef ref, ThemeMode mode) async {
  final p = ref.read(sharedPrefsProvider);

  final safe = (mode == ThemeMode.light) ? ThemeMode.light : ThemeMode.dark;
  ref.read(themeModeProvider.notifier).state = safe;

  await p.setString(_kTheme, safe == ThemeMode.light ? "light" : "dark");
}
