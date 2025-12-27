import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

const _kAuth = "adminAuth";
const _kTheme = "adminTheme";

// Must match ApiClient cookie keys
const _kCookieJar = "api_cookies";
const _kLegacyCookie = "api_cookie";

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError("sharedPrefsProvider must be overridden in main()");
});

final authProvider = StateProvider<bool>((ref) => false);
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

final bootstrapProvider = Provider<Future<void>>((ref) async {
  final p = ref.read(sharedPrefsProvider);

  // theme (light/dark only)
  final t = p.getString(_kTheme) ?? "dark";
  ref.read(themeModeProvider.notifier).state = (t == "light")
      ? ThemeMode.light
      : ThemeMode.dark;

  // auth
  final authed = p.getBool(_kAuth) ?? false;

  // If UI thinks authed but there is no session cookie -> force logout
  final hasCookieJar =
      (p.getString(_kCookieJar)?.trim().isNotEmpty ?? false) ||
      (p.getString(_kLegacyCookie)?.trim().isNotEmpty ?? false);

  final safeAuthed = authed && hasCookieJar;

  if (authed && !hasCookieJar) {
    await p.setBool(_kAuth, false);
  }

  ref.read(authProvider.notifier).state = safeAuthed;
});

Future<void> setAuthed(WidgetRef ref, bool v) async {
  final p = ref.read(sharedPrefsProvider);
  await p.setBool(_kAuth, v);
  ref.read(authProvider.notifier).state = v;
}

Future<void> toggleTheme(WidgetRef ref) async {
  final p = ref.read(sharedPrefsProvider);
  final current = ref.read(themeModeProvider);

  final next = current == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  ref.read(themeModeProvider.notifier).state = next;

  await p.setString(_kTheme, next == ThemeMode.light ? "light" : "dark");
}

Future<void> setThemeMode(WidgetRef ref, ThemeMode mode) async {
  final p = ref.read(sharedPrefsProvider);

  final safe = (mode == ThemeMode.light) ? ThemeMode.light : ThemeMode.dark;
  ref.read(themeModeProvider.notifier).state = safe;

  await p.setString(_kTheme, safe == ThemeMode.light ? "light" : "dark");
}

/// Clears UI auth + stored session cookies
Future<void> logout(WidgetRef ref) async {
  final p = ref.read(sharedPrefsProvider);
  await p.setBool(_kAuth, false);
  await p.remove(_kCookieJar);
  await p.remove(_kLegacyCookie);
  ref.read(authProvider.notifier).state = false;
}
