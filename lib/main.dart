import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

import "app.dart";
import "core/config.dart";
import "core/prefs.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load config (base URL + migration from old :3000 values)
  await AppConfig.init();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const GeofenceAdminApp(),
    ),
  );
}
