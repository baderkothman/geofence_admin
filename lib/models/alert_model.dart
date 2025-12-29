// D:\geofence_project\geofence_admin\lib\models\alert_model.dart

/// Represents a single geofence alert event emitted by the backend.
///
/// The backend can return keys in either `snake_case` or `camelCase`.
/// This model tolerates both for easier integration across different APIs.
///
/// Expected alert types:
/// - "enter": user entered the zone
/// - "exit" : user exited the zone
///
/// Notes:
/// - `occurredAt` is stored as raw string from the server.
/// - `occurredAtDate` attempts parsing into a `DateTime`.
/// - `occurredAtLocalText` is a best-effort local time display string.
class AlertItem {
  /// Unique alert identifier.
  final int id;

  /// The user who generated this alert.
  final int userId;

  /// Optional username (if the API enriches the alert with user info).
  final String? username;

  /// Normalized type string (usually "enter" or "exit").
  final String type;

  /// Raw server timestamp (string).
  final String occurredAt;

  /// Optional latitude at time of alert (if provided by backend).
  final double? latitude;

  /// Optional longitude at time of alert (if provided by backend).
  final double? longitude;

  const AlertItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.occurredAt,
    this.username,
    this.latitude,
    this.longitude,
  });

  /// Converts dynamic values to int safely.
  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  /// Converts dynamic values to double safely.
  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// Converts dynamic values to string safely.
  static String _asString(dynamic v, {String fallback = ""}) {
    if (v == null) return fallback;
    return v.toString();
  }

  /// Creates an [AlertItem] from JSON.
  ///
  /// Supports:
  /// - `id`
  /// - `user_id` or `userId`
  /// - `alert_type` or `type`
  /// - `occurred_at` or `occurredAt`
  factory AlertItem.fromJson(Map<String, dynamic> j) {
    final id = _asInt(j["id"]);
    final userId = _asInt(j["user_id"] ?? j["userId"]);

    final type = _asString(j["alert_type"] ?? j["type"]).trim().toLowerCase();
    final occurredAt = _asString(j["occurred_at"] ?? j["occurredAt"]);

    return AlertItem(
      id: id,
      userId: userId,
      username: j["username"]?.toString(),
      type: type,
      occurredAt: occurredAt,
      latitude: _asDouble(j["latitude"]),
      longitude: _asDouble(j["longitude"]),
    );
  }

  /// True when this alert is explicitly an "enter".
  bool get isEnter => type == "enter";

  /// True when this alert is an "exit" OR any non-empty type that is not "enter".
  ///
  /// This fallback makes the UI robust to unexpected "exit-like" type strings.
  bool get isExit => type == "exit" || (!isEnter && type.isNotEmpty);

  /// Parses [occurredAt] into a `DateTime` if possible.
  DateTime? get occurredAtDate => DateTime.tryParse(occurredAt);

  /// A display-friendly local timestamp text, best-effort.
  String get occurredAtLocalText {
    final d = occurredAtDate;
    if (d == null) return occurredAt;
    return d.toLocal().toString().split(".").first;
  }

  /// User label used in UI when username is missing.
  String get whoLabel => (username != null && username!.trim().isNotEmpty)
      ? username!
      : "User #$userId";

  /// UI title text for the alert.
  String get titleText => isEnter ? "Entered zone" : "Left zone";
}

/// Backward-compatible type alias for older code that used `AlertModel`.
typedef AlertModel = AlertItem;
