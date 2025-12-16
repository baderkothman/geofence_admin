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
  });

  factory User.fromJson(Map<String, dynamic> j) {
    double? d(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return User(
      id: (j["id"] as num).toInt(),
      username: (j["username"] ?? "").toString(),
      fullName: j["full_name"]?.toString(),
      phone: j["phone"]?.toString(),
      email: j["email"]?.toString(),
      role: (j["role"] ?? "").toString(),
      zoneCenterLat: d(j["zone_center_lat"]),
      zoneCenterLng: d(j["zone_center_lng"]),
      zoneRadiusM: d(j["zone_radius_m"]),
      insideZone: j["inside_zone"],
      lastSeen: j["last_seen"]?.toString(),
      lastLatitude: d(j["last_latitude"]),
      lastLongitude: d(j["last_longitude"]),
    );
  }

  bool get hasZone =>
      zoneCenterLat != null && zoneCenterLng != null && zoneRadiusM != null;

  bool get isInside {
    final v = insideZone;
    return v == true || v == 1 || v == "1";
  }

  String get contact {
    if (phone != null && phone!.trim().isNotEmpty) return phone!;
    if (email != null && email!.trim().isNotEmpty) return email!;
    return "—";
  }
}

/// Backward compatible name (so old code using UserModel won't break)
typedef UserModel = User;
