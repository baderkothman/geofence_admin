import "dart:async";
import "dart:convert";
import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";
import "config.dart";

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiHttpException extends ApiException {
  final int statusCode;
  final String method;
  final Uri uri;
  final String responseBody;

  ApiHttpException({
    required this.statusCode,
    required this.method,
    required this.uri,
    required this.responseBody,
  }) : super("HTTP $statusCode $method $uri: $responseBody");
}

class ApiAuthException extends ApiHttpException {
  ApiAuthException({
    required super.statusCode,
    required super.method,
    required super.uri,
    required super.responseBody,
  });
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  // New: cookie jar storage (multiple cookies)
  static const String cookieJarKey = "api_cookies";
  static const String _legacyCookieKey = "api_cookie";

  static bool _cookieLoaded = false;
  static final Map<String, String> _cookies = {}; // name -> value

  Future<void> _ensureCookiesLoaded() async {
    if (_cookieLoaded) return;
    _cookieLoaded = true;

    final prefs = await SharedPreferences.getInstance();

    // Preferred: JSON map
    final jarJson = prefs.getString(cookieJarKey);
    if (jarJson != null && jarJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(jarJson);
        if (decoded is Map) {
          _cookies
            ..clear()
            ..addAll(decoded.map((k, v) => MapEntry("$k", "$v")));
          return;
        }
      } catch (_) {
        // fall through to legacy
      }
    }

    // Legacy: single cookie string "sid=...."
    final legacy = prefs.getString(_legacyCookieKey);
    if (legacy != null && legacy.trim().isNotEmpty) {
      final kv = _parseCookiePairs(legacy);
      _cookies
        ..clear()
        ..addAll(kv);
      // migrate to jar
      await _saveCookieJar();
    }
  }

  Future<void> _saveCookieJar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cookieJarKey, jsonEncode(_cookies));
  }

  Future<void> clearCookies() async {
    _cookies.clear();
    _cookieLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cookieJarKey);
    await prefs.remove(_legacyCookieKey);
  }

  String? _cookieHeaderValue() {
    if (_cookies.isEmpty) return null;
    // "a=b; c=d"
    return _cookies.entries.map((e) => "${e.key}=${e.value}").join("; ");
  }

  void _captureSetCookie(http.Response res) {
    final raw = res.headers["set-cookie"];
    if (raw == null || raw.trim().isEmpty) return;

    final parts = _splitSetCookieHeader(raw);
    bool changed = false;

    for (final p in parts) {
      final first = p.split(";").first.trim(); // "sid=abc"
      final eq = first.indexOf("=");
      if (eq <= 0) continue;

      final name = first.substring(0, eq).trim();
      final value = first.substring(eq + 1).trim();

      if (name.isEmpty) continue;

      // If server clears cookie with empty value, remove it
      if (value.isEmpty) {
        if (_cookies.remove(name) != null) changed = true;
      } else {
        if (_cookies[name] != value) {
          _cookies[name] = value;
          changed = true;
        }
      }
    }

    if (changed) {
      // ignore: unawaited_futures
      _saveCookieJar();
    }
  }

  Uri _u(String path) {
    final p = path.startsWith("/") ? path : "/$path";
    return Uri.parse("${AppConfig.baseUrl}$p");
  }

  Future<Map<String, String>> _headers({bool json = true}) async {
    await _ensureCookiesLoaded();
    final cookie = _cookieHeaderValue();

    return {
      "Accept": "application/json",
      if (json) "Content-Type": "application/json",
      if (cookie != null) "Cookie": cookie,
    };
  }

  Future<http.Response> _withTimeout(Future<http.Response> f) {
    return f.timeout(const Duration(seconds: 20));
  }

  String _bodyText(http.Response res) {
    // safer than res.body for non-utf8 / odd encodings
    try {
      return utf8.decode(res.bodyBytes);
    } catch (_) {
      return res.body;
    }
  }

  void _debugLog(String msg) {
    if (kDebugMode) {
      // ignore: avoid_print
      print(msg);
    }
  }

  Future<http.Response> _request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    _debugLog("[API] $method $uri");
    if (body != null && kDebugMode) {
      _debugLog("[API] body: $body");
    }

    late http.Response res;

    switch (method) {
      case "GET":
        res = await _withTimeout(_client.get(uri, headers: headers));
        break;
      case "POST":
        res = await _withTimeout(
          _client.post(uri, headers: headers, body: body),
        );
        break;
      case "PUT":
        res = await _withTimeout(
          _client.put(uri, headers: headers, body: body),
        );
        break;
      case "DELETE":
        res = await _withTimeout(
          _client.delete(uri, headers: headers, body: body),
        );
        break;
      default:
        throw ApiException("Unsupported method: $method");
    }

    _captureSetCookie(res);

    if (kDebugMode) {
      _debugLog("[API] status: ${res.statusCode}");
      final t = _bodyText(res);
      if (t.trim().isNotEmpty) _debugLog("[API] response: $t");
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw ApiAuthException(
        statusCode: res.statusCode,
        method: method,
        uri: uri,
        responseBody: _bodyText(res),
      );
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiHttpException(
        statusCode: res.statusCode,
        method: method,
        uri: uri,
        responseBody: _bodyText(res),
      );
    }

    return res;
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final uri = _u(path);
    final res = await _request(
      "GET",
      uri,
      headers: await _headers(json: false),
    );

    final decoded = jsonDecode(_bodyText(res));
    if (decoded is Map<String, dynamic>) return decoded;
    throw ApiException("Invalid JSON (expected object) from GET $uri");
  }

  Future<List<dynamic>> getList(String path) async {
    final uri = _u(path);
    final res = await _request(
      "GET",
      uri,
      headers: await _headers(json: false),
    );

    final decoded = jsonDecode(_bodyText(res));
    if (decoded is List) return decoded;
    throw ApiException("Invalid JSON (expected list) from GET $uri");
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = _u(path);
    final res = await _request(
      "POST",
      uri,
      headers: await _headers(),
      body: jsonEncode(body),
    );

    final text = _bodyText(res).trim();
    if (text.isEmpty) return {"ok": true};

    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    return {"ok": true};
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = _u(path);
    final res = await _request(
      "PUT",
      uri,
      headers: await _headers(),
      body: jsonEncode(body),
    );

    final text = _bodyText(res).trim();
    if (text.isEmpty) return {"ok": true};

    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    return {"ok": true};
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _u(path);
    final res = await _request(
      "DELETE",
      uri,
      headers: await _headers(json: body != null),
      body: body == null ? null : jsonEncode(body),
    );

    final text = _bodyText(res).trim();
    if (text.isEmpty) return {"ok": true};

    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    return {"ok": true};
  }
}

/// Parse "a=b; c=d" into map
Map<String, String> _parseCookiePairs(String cookieHeader) {
  final out = <String, String>{};
  final parts = cookieHeader.split(";");
  for (final p in parts) {
    final s = p.trim();
    if (s.isEmpty) continue;
    final eq = s.indexOf("=");
    if (eq <= 0) continue;
    final k = s.substring(0, eq).trim();
    final v = s.substring(eq + 1).trim();
    if (k.isNotEmpty) out[k] = v;
  }
  return out;
}

/// Safely split a combined Set-Cookie header into individual cookie strings.
/// Handles commas inside Expires=... attribute.
List<String> _splitSetCookieHeader(String header) {
  final out = <String>[];
  final buf = StringBuffer();
  bool inExpires = false;

  // We track "expires=" case-insensitively
  String tail = "";

  for (int i = 0; i < header.length; i++) {
    final ch = header[i];
    buf.write(ch);

    // update tail
    tail = (tail + ch).toLowerCase();
    if (tail.length > 12) tail = tail.substring(tail.length - 12);

    if (!inExpires && tail.contains("expires=")) {
      inExpires = true;
    }

    if (inExpires && ch == ";") {
      inExpires = false;
      // reset tail to avoid false positives
      tail = "";
    }

    // Separator comma (only if NOT inside expires)
    if (!inExpires && ch == ",") {
      final s = buf.toString();
      // remove the comma from current cookie
      final cleaned = s.substring(0, s.length - 1).trim();
      if (cleaned.isNotEmpty) out.add(cleaned);
      buf.clear();
      tail = "";
    }
  }

  final last = buf.toString().trim();
  if (last.isNotEmpty) out.add(last);

  return out;
}
