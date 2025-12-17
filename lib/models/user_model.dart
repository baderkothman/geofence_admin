class User {
  final int id;
  final String username;
  final String? fullName;
  final String? phone;
  final String? email;
  final String role;

  final double? zoneCenterLat;
  final double? zoneCenterLng;
  final double? zoneRadiusM;

  final dynamic insideZone; // bool/int/string
  final String? lastSeen;
  final double? lastLatitude;
  final double? lastLongitude;

  // Optional: if backend ever sends a combined contact field
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

  bool get hasZone =>
      zoneCenterLat != null && zoneCenterLng != null && zoneRadiusM != null;

  bool get isInside {
    final v = insideZone;
    if (v == true) return true;
    if (v == false) return false;
    if (v is num) return v.toInt() == 1;

    final s = v?.toString().trim().toLowerCase();
    if (s == "1" || s == "true" || s == "yes" || s == "inside") return true;
    return false;
  }

  String get displayName {
    final n = (fullName ?? "").trim();
    return n.isNotEmpty ? n : username;
  }

  DateTime? get lastSeenDate =>
      lastSeen == null ? null : DateTime.tryParse(lastSeen!);

  String get lastSeenLocalText {
    final d = lastSeenDate;
    if (d == null) return "Never";
    return d.toLocal().toString().split(".").first;
  }

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

/// Backward compatible name (so old code using UserModel won't break)
typedef UserModel = User;
