import "package:shared_preferences/shared_preferences.dart";

class AppConfig {
  static const String _defaultBaseUrl = "http://192.168.56.1:3000";

  static String baseUrl = _defaultBaseUrl;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString("api_base_url") ?? _defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("api_base_url", url);
    baseUrl = url;
  }

  static String get defaultBaseUrl => _defaultBaseUrl;
}
