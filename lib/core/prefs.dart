// D:\geofence_project\geofence_admin\lib\core\prefs.dart

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

/// SharedPreferences key: persisted auth flag for admin UI.
const _kAuth = "adminAuth";

/// SharedPreferences key: persisted theme preference ("light" or "dark").
const _kTheme = "adminTheme";

/// SharedPreferences key: preferred cookie jar storage (JSON map).
const _kCookieJar = "api_cookies";

/// SharedPreferences key: legacy single-cookie storage (string).
const _kLegacyCookie = "api_cookie";

/// Provider that exposes a SharedPreferences instance.
///
/// This must be overridden in main() once prefs are loaded.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError("sharedPrefsProvider must be overridden in main()");
});

/// Provider holding whether the UI considers the admin authenticated.
final authProvider = StateProvider<bool>((ref) => false);

/// Provider holding current theme mode (light/dark only).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

/// Bootstrap provider to load persisted settings into providers.
///
/// Performs:
/// - Theme preference load
/// - Auth flag load
/// - Safety check: if UI says authed but cookies are missing, force logout
final bootstrapProvider = Provider<Future<void>>((ref) async {
  final p = ref.read(sharedPrefsProvider);

  // Restore theme.
  final t = p.getString(_kTheme) ?? "dark";
  ref.read(themeModeProvider.notifier).state = (t == "light")
      ? ThemeMode.light
      : ThemeMode.dark;

  // Restore auth.
  final authed = p.getBool(_kAuth) ?? false;

  // If auth is true but there is no cookie stored, the session is not usable.
  final hasCookieJar =
      (p.getString(_kCookieJar)?.trim().isNotEmpty ?? false) ||
      (p.getString(_kLegacyCookie)?.trim().isNotEmpty ?? false);

  final safeAuthed = authed && hasCookieJar;

  // If inconsistent state is found, persist correction.
  if (authed && !hasCookieJar) {
    await p.setBool(_kAuth, false);
  }

  ref.read(authProvider.notifier).state = safeAuthed;
});

/// Sets the UI authenticated flag and persists it.
Future<void> setAuthed(WidgetRef ref, bool v) async {
  final p = ref.read(sharedPrefsProvider);
  await p.setBool(_kAuth, v);
  ref.read(authProvider.notifier).state = v;
}

/// Toggles between light and dark theme and persists the choice.
Future<void> toggleTheme(WidgetRef ref) async {
  final p = ref.read(sharedPrefsProvider);
  final current = ref.read(themeModeProvider);

  final next = current == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  ref.read(themeModeProvider.notifier).state = next;

  await p.setString(_kTheme, next == ThemeMode.light ? "light" : "dark");
}

/// Sets theme mode with a safe constraint (light/dark only) and persists it.
Future<void> setThemeMode(WidgetRef ref, ThemeMode mode) async {
  final p = ref.read(sharedPrefsProvider);

  // Avoid system mode to keep behavior predictable for this admin app.
  final safe = (mode == ThemeMode.light) ? ThemeMode.light : ThemeMode.dark;
  ref.read(themeModeProvider.notifier).state = safe;

  await p.setString(_kTheme, safe == ThemeMode.light ? "light" : "dark");
}

/// Logs out the admin:
/// - clears auth flag
/// - clears stored cookies
/// - updates provider state
Future<void> logout(WidgetRef ref) async {
  final p = ref.read(sharedPrefsProvider);
  await p.setBool(_kAuth, false);
  await p.remove(_kCookieJar);
  await p.remove(_kLegacyCookie);
  ref.read(authProvider.notifier).state = false;
}
