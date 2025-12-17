class AlertItem {
  final int id;
  final int userId;
  final String? username;
  final String type; // enter/exit
  final String occurredAt;
  final double? latitude;
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

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static String _asString(dynamic v, {String fallback = ""}) {
    if (v == null) return fallback;
    return v.toString();
  }

  factory AlertItem.fromJson(Map<String, dynamic> j) {
    // tolerate snake_case or camelCase
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

  bool get isEnter => type == "enter";
  bool get isExit => type == "exit" || (!isEnter && type.isNotEmpty);

  DateTime? get occurredAtDate => DateTime.tryParse(occurredAt);

  String get occurredAtLocalText {
    final d = occurredAtDate;
    if (d == null) return occurredAt;
    return d.toLocal().toString().split(".").first;
  }

  String get whoLabel => (username != null && username!.trim().isNotEmpty)
      ? username!
      : "User #$userId";

  String get titleText => isEnter ? "Entered zone" : "Left zone";
}

/// Backward compatible name (so old code using AlertModel won't break)
typedef AlertModel = AlertItem;
