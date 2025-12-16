import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

const _kAuth = "adminAuth";
const _kTheme = "adminTheme"; // system/light/dark

/// This MUST be overridden in main.dart
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError("sharedPrefsProvider must be overridden in main()");
});

final authProvider = StateProvider<bool>((ref) => false);
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// App bootstrap (loads auth + theme once)
final bootstrapProvider = Provider<Future<void>>((ref) async {
  final p = ref.read(sharedPrefsProvider);

  // auth
  final authed = p.getBool(_kAuth) ?? false;
  ref.read(authProvider.notifier).state = authed;

  // theme
  final t = p.getString(_kTheme) ?? "system";
  ref.read(themeModeProvider.notifier).state = t == "light"
      ? ThemeMode.light
      : t == "dark"
      ? ThemeMode.dark
      : ThemeMode.system;
});

Future<void> setAuthed(WidgetRef ref, bool v) async {
  final p = ref.read(sharedPrefsProvider);
  await p.setBool(_kAuth, v);
  ref.read(authProvider.notifier).state = v;
}

Future<void> cycleTheme(WidgetRef ref) async {
  final p = ref.read(sharedPrefsProvider);
  final current = ref.read(themeModeProvider);

  final next = current == ThemeMode.system
      ? ThemeMode.light
      : current == ThemeMode.light
      ? ThemeMode.dark
      : ThemeMode.system;

  ref.read(themeModeProvider.notifier).state = next;

  final str = next == ThemeMode.light
      ? "light"
      : next == ThemeMode.dark
      ? "dark"
      : "system";

  await p.setString(_kTheme, str);
}

Future<void> setThemeMode(WidgetRef ref, ThemeMode mode) async {
  final p = await SharedPreferences.getInstance();
  ref.read(themeModeProvider.notifier).state = mode;

  final str = mode == ThemeMode.light
      ? "light"
      : mode == ThemeMode.dark
      ? "dark"
      : "system";

  await p.setString("adminTheme", str);
}
