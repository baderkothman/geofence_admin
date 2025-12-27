import "package:shared_preferences/shared_preferences.dart";

class AppConfig {
  static const String _prefsKey = "api_base_url";

  static const String serverIp = "192.168.1.21";
  static const String serverPort = "4001";

  static const String lanUrl = "http://$serverIp:$serverPort";
  static const String androidEmulatorUrl = "http://10.0.2.2:$serverPort";
  static const String iosSimulatorUrl = "http://localhost:$serverPort";

  static const Map<String, String> presetUrls = {
    "LAN (real device on Wi-Fi)": lanUrl,
    "Android Emulator (10.0.2.2)": androidEmulatorUrl,
    "iOS Simulator (localhost)": iosSimulatorUrl,
  };

  static String baseUrl = lanUrl;

  static String get defaultBaseUrl {
    const dartDefine = String.fromEnvironment("API_BASE_URL", defaultValue: "");
    if (dartDefine.trim().isNotEmpty) return _normalize(dartDefine);
    return lanUrl;
  }

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

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final v = _normalize(url);
    await prefs.setString(_prefsKey, v);
    baseUrl = v;
  }

  static Future<void> resetBaseUrlToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = _normalize(defaultBaseUrl);
    await prefs.setString(_prefsKey, baseUrl);
  }

  static String _normalize(String url) {
    var v = url.trim();

    // If user typed without scheme, default to http
    if (!v.startsWith("http://") && !v.startsWith("https://")) {
      v = "http://$v";
    }

    while (v.endsWith("/")) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }
}
