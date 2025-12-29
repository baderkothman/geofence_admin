// D:\geofence_project\geofence_admin\lib\models\user_model.dart

/// Represents a user as returned by the geofence backend.
///
/// This model supports mixed naming conventions (`snake_case` and `camelCase`)
/// so the same app can work with multiple backends or versions.
///
/// Zone fields:
/// - `zoneCenterLat`, `zoneCenterLng`: circle center
/// - `zoneRadiusM`: radius in meters
///
/// Live tracking fields (optional):
/// - `insideZone`: can be bool/int/string
/// - `lastSeen`, `lastLatitude`, `lastLongitude`
class User {
  /// Primary key.
  final int id;

  /// Username/handle used for login and display.
  final String username;

  /// Optional full name.
  final String? fullName;

  /// Optional phone number.
  final String? phone;

  /// Optional email.
  final String? email;

  /// User role (e.g., "admin", "user").
  final String role;

  /// Zone center latitude (meters-based circle).
  final double? zoneCenterLat;

  /// Zone center longitude (meters-based circle).
  final double? zoneCenterLng;

  /// Zone radius in meters.
  final double? zoneRadiusM;

  /// "Inside zone" indicator with flexible types (bool/int/string).
  final dynamic insideZone;

  /// Last seen timestamp as raw string.
  final String? lastSeen;

  /// Last known latitude (if tracked).
  final double? lastLatitude;

  /// Last known longitude (if tracked).
  final double? lastLongitude;

  /// Optional combined contact value if backend returns a single field.
  final String? contactValue;

  const User({
    required this.id,
    required this.username,
    required this.role,
    this.fullName,
    this.phone,
    this.email,
    this.zoneCenterLat,
    this.zoneCenterLng,
    this.zoneRadiusM,
    this.insideZone,
    this.lastSeen,
    this.lastLatitude,
    this.lastLongitude,
    this.contactValue,
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

  /// Creates a [User] from backend JSON.
  ///
  /// Supported keys:
  /// - `id`
  /// - `username`
  /// - `role`
  /// - `full_name` / `fullName`
  /// - `phone` / `mobile`
  /// - `email`
  /// - `zone_center_lat` / `zoneCenterLat`
  /// - `zone_center_lng` / `zoneCenterLng`
  /// - `zone_radius_m` / `zoneRadiusM`
  /// - `inside_zone` / `insideZone`
  /// - `last_seen` / `lastSeen`
  /// - `last_latitude` / `lastLatitude`
  /// - `last_longitude` / `lastLongitude`
  /// - `contact`
  factory User.fromJson(Map<String, dynamic> j) {
    return User(
      id: _asInt(j["id"]),
      username: _asString(j["username"]).trim(),
      fullName: (j["full_name"] ?? j["fullName"])?.toString(),
      phone: (j["phone"] ?? j["mobile"])?.toString(),
      email: (j["email"])?.toString(),
      role: _asString(j["role"]).trim(),
      zoneCenterLat: _asDouble(j["zone_center_lat"] ?? j["zoneCenterLat"]),
      zoneCenterLng: _asDouble(j["zone_center_lng"] ?? j["zoneCenterLng"]),
      zoneRadiusM: _asDouble(j["zone_radius_m"] ?? j["zoneRadiusM"]),
      insideZone: j["inside_zone"] ?? j["insideZone"],
      lastSeen: (j["last_seen"] ?? j["lastSeen"])?.toString(),
      lastLatitude: _asDouble(j["last_latitude"] ?? j["lastLatitude"]),
      lastLongitude: _asDouble(j["last_longitude"] ?? j["lastLongitude"]),
      contactValue: j["contact"]?.toString(),
    );
  }

  /// True when the user has a complete zone assigned.
  bool get hasZone =>
      zoneCenterLat != null && zoneCenterLng != null && zoneRadiusM != null;

  /// Normalizes `insideZone` to a boolean.
  ///
  /// Accepts:
  /// - true/false
  /// - 1/0 (number)
  /// - "1", "true", "yes", "inside"
  bool get isInside {
    final v = insideZone;
    if (v == true) return true;
    if (v == false) return false;
    if (v is num) return v.toInt() == 1;

    final s = v?.toString().trim().toLowerCase();
    if (s == "1" || s == "true" || s == "yes" || s == "inside") return true;
    return false;
  }

  /// Best display name for UI.
  ///
  /// Prefers `fullName` if present, otherwise falls back to `username`.
  String get displayName {
    final n = (fullName ?? "").trim();
    return n.isNotEmpty ? n : username;
  }

  /// Parses [lastSeen] into a `DateTime` if possible.
  DateTime? get lastSeenDate =>
      lastSeen == null ? null : DateTime.tryParse(lastSeen!);

  /// Local-time friendly display for last seen.
  String get lastSeenLocalText {
    final d = lastSeenDate;
    if (d == null) return "Never";
    return d.toLocal().toString().split(".").first;
  }

  /// Best contact field for UI.
  ///
  /// Priority:
  /// 1) `contactValue`
  /// 2) `phone`
  /// 3) `email`
  /// 4) em dash placeholder
  String get contact {
    final c = (contactValue ?? "").trim();
    if (c.isNotEmpty) return c;

    final p = (phone ?? "").trim();
    if (p.isNotEmpty) return p;

    final e = (email ?? "").trim();
    if (e.isNotEmpty) return e;

    return "—";
  }
}

/// Backward-compatible type alias for older code that used `UserModel`.
typedef UserModel = User;
