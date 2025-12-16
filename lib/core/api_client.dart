import "dart:convert";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";
import "config.dart";

class ApiClient {
  final http.Client _client = http.Client();

  static const _cookieKey = "api_cookie";
  static bool _cookieLoaded = false;
  static String? _cookie; // "sid=...." etc.

  Future<void> _ensureCookie() async {
    if (_cookieLoaded) return;
    _cookieLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    _cookie = prefs.getString(_cookieKey);
  }

  Future<void> _saveCookie(String cookie) async {
    _cookie = cookie;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cookieKey, cookie);
  }

  void _captureSetCookie(http.Response res) {
    final setCookie = res.headers["set-cookie"];
    if (setCookie == null || setCookie.isEmpty) return;

    // very common: "sid=abc; Path=/; HttpOnly"
    final first = setCookie.split(";").first.trim();
    if (first.isNotEmpty) {
      // ignore: unawaited_futures
      _saveCookie(first);
    }
  }

  Uri _u(String path) => Uri.parse("${AppConfig.baseUrl}$path");

  Future<Map<String, String>> _headers({bool json = true}) async {
    await _ensureCookie();
    return {
      if (json) "Content-Type": "application/json",
      if (_cookie != null) "Cookie": _cookie!,
    };
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final res = await _client.get(
      _u(path),
      headers: await _headers(json: false),
    );
    _captureSetCookie(res);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("HTTP ${res.statusCode}: ${res.body}");
    }

    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw Exception("Invalid JSON response");
  }

  Future<List<dynamic>> getList(String path) async {
    final res = await _client.get(
      _u(path),
      headers: await _headers(json: false),
    );
    _captureSetCookie(res);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("HTTP ${res.statusCode}: ${res.body}");
    }

    final decoded = jsonDecode(res.body);
    if (decoded is List) return decoded;
    throw Exception("Invalid JSON response");
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await _client.post(
      _u(path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    _captureSetCookie(res);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("HTTP ${res.statusCode}: ${res.body}");
    }

    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {"ok": true};
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await _client.put(
      _u(path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    _captureSetCookie(res);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("HTTP ${res.statusCode}: ${res.body}");
    }

    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {"ok": true};
  }
}
