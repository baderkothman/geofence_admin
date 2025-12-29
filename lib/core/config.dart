// D:\geofence_project\geofence_admin\lib\core\config.dart

import "package:shared_preferences/shared_preferences.dart";

/// Central app configuration for the API base URL.
///
/// The base URL can be:
/// - A compile-time override via `--dart-define=API_BASE_URL=...`
/// - A persisted value in SharedPreferences
/// - A default LAN URL (serverIp:serverPort)
///
/// The URL is normalized to:
/// - include scheme (defaults to http)
/// - remove trailing slashes
class AppConfig {
  static const String _prefsKey = "api_base_url";

  /// Your backend host on LAN.
  static const String serverIp = "192.168.1.21";

  /// Your backend port.
  static const String serverPort = "4001";

  /// Default URL for real devices on the same Wi-Fi.
  static const String lanUrl = "http://$serverIp:$serverPort";

  /// Special address for Android emulator to reach host machine.
  static const String androidEmulatorUrl = "http://10.0.2.2:$serverPort";

  /// iOS simulator can typically reach localhost directly.
  static const String iosSimulatorUrl = "http://localhost:$serverPort";

  /// Preset options that can be shown in a UI picker (if you add one).
  static const Map<String, String> presetUrls = {
    "LAN (real device on Wi-Fi)": lanUrl,
    "Android Emulator (10.0.2.2)": androidEmulatorUrl,
    "iOS Simulator (localhost)": iosSimulatorUrl,
  };

  /// Current runtime base URL used by ApiClient.
  static String baseUrl = lanUrl;

  /// Default base URL decision:
  /// - prefers dart-define if provided
  /// - otherwise uses LAN URL
  static String get defaultBaseUrl {
    const dartDefine = String.fromEnvironment("API_BASE_URL", defaultValue: "");
    if (dartDefine.trim().isNotEmpty) return _normalize(dartDefine);
    return lanUrl;
  }

  /// Loads baseUrl from SharedPreferences if present; otherwise stores the default.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);

    if (saved == null || saved.trim().isEmpty) {
      baseUrl = _normalize(defaultBaseUrl);
      await prefs.setString(_prefsKey, baseUrl);
    } else {
      baseUrl = _normalize(saved);
    }
  }

  /// Persists a new base URL and updates runtime value.
  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final v = _normalize(url);
    await prefs.setString(_prefsKey, v);
    baseUrl = v;
  }

  /// Resets base URL to computed default and persists it.
  static Future<void> resetBaseUrlToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = _normalize(defaultBaseUrl);
    await prefs.setString(_prefsKey, baseUrl);
  }

  /// Normalizes a URL string to a consistent format.
  static String _normalize(String url) {
    var v = url.trim();

    // Add scheme if missing.
    if (!v.startsWith("http://") && !v.startsWith("https://")) {
      v = "http://$v";
    }

    // Remove trailing slashes to avoid double-slash issues when concatenating paths.
    while (v.endsWith("/")) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }
}
