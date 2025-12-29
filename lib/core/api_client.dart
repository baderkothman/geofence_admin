// D:\geofence_project\geofence_admin\lib\core\api_client.dart

import "dart:async";
import "dart:convert";
import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";
import "config.dart";

/// Base exception type for API errors in this app.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

/// Exception for non-2xx responses, including full context.
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

/// Exception for auth failures (401/403), allowing callers to react differently.
class ApiAuthException extends ApiHttpException {
  ApiAuthException({
    required super.statusCode,
    required super.method,
    required super.uri,
    required super.responseBody,
  });
}

/// Minimal HTTP client wrapper that:
/// - Builds URLs using `AppConfig.baseUrl`
/// - Sends JSON requests
/// - Captures and persists cookies (session management)
/// - Throws rich exceptions for errors
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  /// Preferred cookie storage key: JSON map `{ cookieName: cookieValue }`.
  static const String cookieJarKey = "api_cookies";

  /// Legacy cookie storage key: a single string like "sid=....".
  static const String _legacyCookieKey = "api_cookie";

  /// Whether cookies have been loaded from SharedPreferences into memory.
  static bool _cookieLoaded = false;

  /// In-memory cookie jar (cookie name -> value).
  static final Map<String, String> _cookies = {};

  /// Loads cookies from storage once per app lifecycle.
  ///
  /// Migration behavior:
  /// - If legacy cookie exists, it is parsed into the jar and stored as JSON map.
  Future<void> _ensureCookiesLoaded() async {
    if (_cookieLoaded) return;
    _cookieLoaded = true;

    final prefs = await SharedPreferences.getInstance();

    // Preferred format: JSON object map.
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
        // If JSON is invalid, fall back to legacy.
      }
    }

    // Legacy format: a single cookie header string.
    final legacy = prefs.getString(_legacyCookieKey);
    if (legacy != null && legacy.trim().isNotEmpty) {
      final kv = _parseCookiePairs(legacy);
      _cookies
        ..clear()
        ..addAll(kv);
      await _saveCookieJar();
    }
  }

  /// Persists the in-memory cookie jar to SharedPreferences.
  Future<void> _saveCookieJar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cookieJarKey, jsonEncode(_cookies));
  }

  /// Clears cookies in memory and in SharedPreferences.
  Future<void> clearCookies() async {
    _cookies.clear();
    _cookieLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cookieJarKey);
    await prefs.remove(_legacyCookieKey);
  }

  /// Builds the "Cookie" header value from the in-memory jar.
  String? _cookieHeaderValue() {
    if (_cookies.isEmpty) return null;
    return _cookies.entries.map((e) => "${e.key}=${e.value}").join("; ");
  }

  /// Captures cookies from the HTTP response `set-cookie` header.
  ///
  /// This supports servers that return multiple cookies and handles:
  /// - comma-separated cookie strings
  /// - commas inside `Expires=...` attributes
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

      // If the server clears a cookie by setting empty value, drop it locally.
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
      // Persist in the background; no UI needs to wait for this.
      unawaited(_saveCookieJar());
    }
  }

  /// Builds absolute URI from a relative API path using current base URL.
  Uri _u(String path) {
    final p = path.startsWith("/") ? path : "/$path";
    return Uri.parse("${AppConfig.baseUrl}$p");
  }

  /// Builds HTTP headers, including JSON headers and cookies.
  Future<Map<String, String>> _headers({bool json = true}) async {
    await _ensureCookiesLoaded();
    final cookie = _cookieHeaderValue();

    return {
      "Accept": "application/json",
      if (json) "Content-Type": "application/json",
      if (cookie != null) "Cookie": cookie,
    };
  }

  /// Adds a timeout to HTTP calls to avoid hanging UI indefinitely.
  Future<http.Response> _withTimeout(Future<http.Response> f) {
    return f.timeout(const Duration(seconds: 20));
  }

  /// Decodes response bytes safely into text.
  String _bodyText(http.Response res) {
    try {
      return utf8.decode(res.bodyBytes);
    } catch (_) {
      return res.body;
    }
  }

  /// Debug logging for API calls (only in debug mode).
  void _debugLog(String msg) {
    if (kDebugMode) {
      debugPrint(msg);
    }
  }

  /// Core request executor used by all public methods.
  ///
  /// - Logs request/response when in debug mode.
  /// - Captures cookies from response.
  /// - Throws ApiAuthException for 401/403.
  /// - Throws ApiHttpException for any non-2xx.
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

  /// GET endpoint expecting a JSON object response.
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

  /// GET endpoint expecting a JSON array response.
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

  /// POST JSON request. Returns a JSON object if present; otherwise returns `{ ok: true }`.
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

  /// PUT JSON request. Returns a JSON object if present; otherwise returns `{ ok: true }`.
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

  /// DELETE request with optional JSON body.
  ///
  /// Returns a JSON object if present; otherwise returns `{ ok: true }`.
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

/// Parses a cookie header string like "a=b; c=d" into a name/value map.
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

/// Splits a combined Set-Cookie header into individual cookie strings.
///
/// Some servers combine multiple cookies into one header separated by commas.
/// The tricky part is that `Expires=...` also contains commas. This parser
/// treats commas as separators only when not inside an Expires attribute.
List<String> _splitSetCookieHeader(String header) {
  final out = <String>[];
  final buf = StringBuffer();
  bool inExpires = false;

  // A small rolling window to detect "expires=" case-insensitively.
  String tail = "";

  for (int i = 0; i < header.length; i++) {
    final ch = header[i];
    buf.write(ch);

    tail = (tail + ch).toLowerCase();
    if (tail.length > 12) tail = tail.substring(tail.length - 12);

    if (!inExpires && tail.contains("expires=")) {
      inExpires = true;
    }

    // Expires attribute ends at ';'
    if (inExpires && ch == ";") {
      inExpires = false;
      tail = "";
    }

    // A comma splits cookies only when not inside Expires
    if (!inExpires && ch == ",") {
      final s = buf.toString();
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
