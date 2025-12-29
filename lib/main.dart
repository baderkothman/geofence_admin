// D:\geofence_project\geofence_admin\lib\main.dart

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

import "app.dart";
import "core/config.dart";
import "core/prefs.dart";

/// Application entry point.
///
/// Boot sequence:
/// 1) Ensure Flutter bindings are initialized.
/// 2) Initialize AppConfig (base URL from prefs or defaults).
/// 3) Load SharedPreferences and override the provider for the whole app.
/// 4) Run the app root widget.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppConfig.init();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const GeofenceAdminApp(),
    ),
  );
}
