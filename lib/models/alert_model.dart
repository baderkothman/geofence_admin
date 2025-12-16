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

  factory AlertItem.fromJson(Map<String, dynamic> j) {
    double? d(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return AlertItem(
      id: (j["id"] as num).toInt(),
      userId: (j["user_id"] as num).toInt(),
      username: j["username"]?.toString(),
      type: (j["alert_type"] ?? "").toString(),
      occurredAt: (j["occurred_at"] ?? "").toString(),
      latitude: d(j["latitude"]),
      longitude: d(j["longitude"]),
    );
  }

  bool get isEnter => type == "enter";
}

/// Backward compatible name (so old code using AlertModel won't break)
typedef AlertModel = AlertItem;
