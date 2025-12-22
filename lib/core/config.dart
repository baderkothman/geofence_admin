import "dart:io";
import "package:shared_preferences/shared_preferences.dart";

class AppConfig {
  static const String _prefsKey = "api_base_url";

  /// Override at runtime:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:4001
  /// Or (Android emulator):
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4001
  static const String _dartDefineBaseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: "",
  );

  /// Default for your current LAN (edit if your PC IP changes)
  static const String _fallbackLan = "http://192.168.1.50:4001";

  /// Convenient emulator defaults
  static const String _androidEmulator = "http://10.0.2.2:4001";
  static const String _iosSimulator = "http://localhost:4001";

  static String baseUrl = _fallbackLan;

  static String get defaultBaseUrl {
    if (_dartDefineBaseUrl.trim().isNotEmpty) {
      return _normalize(_dartDefineBaseUrl);
    }

    // Reasonable defaults (can still be overridden in Settings)
    if (Platform.isAndroid) return _androidEmulator; // best for emulator
    if (Platform.isIOS) return _iosSimulator; // best for simulator
    return _fallbackLan; // desktop / real device fallback
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    String? saved = prefs.getString(_prefsKey);

    // If user previously saved an old web baseUrl (:3000), migrate it to :4001
    if (saved != null && saved.isNotEmpty) {
      saved = _migrateTo4001(saved);
      saved = _normalize(saved);
      baseUrl = saved;
      await prefs.setString(_prefsKey, saved);
      return;
    }

    // First install (no saved base url)
    final d = defaultBaseUrl;
    baseUrl = _normalize(d);
    await prefs.setString(_prefsKey, baseUrl);
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final v = _normalize(_migrateTo4001(url));
    await prefs.setString(_prefsKey, v);
    baseUrl = v;
  }

  static Future<void> resetBaseUrlToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    baseUrl = _normalize(defaultBaseUrl);
    await prefs.setString(_prefsKey, baseUrl);
  }

  static String _normalize(String url) {
    var v = url.trim();
    // remove trailing slash to avoid double slashes when joining paths
    while (v.endsWith("/")) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  static String _migrateTo4001(String url) {
    // Convert known old ports to the new API port
    // Examples:
    //   http://192.168.1.50:3000  -> http://192.168.1.50:4001
    //   http://localhost:3000     -> http://localhost:4001
    return url
        .replaceAll(":3000", ":4001")
        .replaceAll("http://192.168.56.1:3000", _fallbackLan);
  }
}
