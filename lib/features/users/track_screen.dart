import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";
import "package:url_launcher/url_launcher.dart";

import "../../core/api_client.dart";
import "../../core/theme/app_tokens.dart";
import "../../models/user_model.dart";

class TrackScreen extends StatefulWidget {
  final int userId;
  final String username;

  const TrackScreen({super.key, required this.userId, required this.username});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  final _api = ApiClient();
  final MapController _map = MapController();
  Timer? _timer;

  UserModel? _user;
  bool _loading = true;
  bool _following = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_following) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    try {
      if (initial) setState(() => _loading = true);

      final raw = await _api.getList("/api/users");
      final users = raw
          .whereType<Map>()
          .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e)))
          .where((u) => u.role != "admin")
          .toList();

      final u = users.firstWhere(
        (x) => x.id == widget.userId,
        orElse: () =>
            users.isNotEmpty ? users.first : UserModel.fromJson(const {}),
      );

      if (!mounted) return;
      setState(() {
        _user = u.id == widget.userId ? u : null;
        _error = _user == null ? "User not found" : null;
        _loading = false;
      });

      // Auto move map to latest location if available
      final lat = _user?.lastLatitude;
      final lng = _user?.lastLongitude;
      if (lat != null && lng != null) {
        final p = LatLng(lat, lng);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _map.move(p, _map.camera.zoom < 15 ? 16 : _map.camera.zoom);
          } catch (_) {}
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to refresh location";
        _loading = false;
      });
    }
  }

  Future<void> _openGoogleMaps() async {
    final lat = _user?.lastLatitude;
    final lng = _user?.lastLongitude;
    if (lat == null || lng == null) return;

    final uri = Uri.parse("https://www.google.com/maps?q=$lat,$lng");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final lat = _user?.lastLatitude;
    final lng = _user?.lastLongitude;
    final hasCoords = lat != null && lng != null;

    final zoneLat = _user?.zoneCenterLat;
    final zoneLng = _user?.zoneCenterLng;
    final zoneRadius = _user?.zoneRadiusM?.toDouble();

    final hasZone = zoneLat != null && zoneLng != null && zoneRadius != null;

    final fallback = const LatLng(33.8938, 35.5018); // Beirut
    final center = hasCoords
        ? LatLng(lat, lng)
        : (hasZone ? LatLng(zoneLat, zoneLng) : fallback);

    return Scaffold(
      appBar: AppBar(
        title: Text("Track • ${widget.username}"),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _following = !_following),
            icon: Icon(_following ? Icons.gps_fixed : Icons.gps_off),
            label: Text(_following ? "Following" : "Paused"),
          ),
          IconButton(
            tooltip: "Refresh now",
            onPressed: () => _load(initial: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? Center(child: Text(_error!))
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Live map",
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hasCoords
                              ? "Showing last known location."
                              : "No location coordinates yet (waiting for mobile user updates).",
                          style: t.bodySmall,
                        ),
                        const SizedBox(height: 12),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppTokens.radius),
                          child: SizedBox(
                            height: 320,
                            width: double.infinity,
                            child: FlutterMap(
                              mapController: _map,
                              options: MapOptions(
                                initialCenter: center,
                                initialZoom: hasCoords ? 16 : 13,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.all,
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                                  userAgentPackageName: "geofence_admin",
                                ),

                                if (hasZone)
                                  CircleLayer(
                                    circles: [
                                      CircleMarker(
                                        point: LatLng(zoneLat, zoneLng),
                                        radius: zoneRadius,
                                        useRadiusInMeter: true,
                                        color: AppTokens.success.withAlpha(30),
                                        borderStrokeWidth: 2,
                                        borderColor: AppTokens.success
                                            .withAlpha(170),
                                      ),
                                    ],
                                  ),

                                MarkerLayer(
                                  markers: [
                                    if (hasZone)
                                      Marker(
                                        point: LatLng(zoneLat, zoneLng),
                                        width: 44,
                                        height: 44,
                                        child: const Icon(
                                          Icons.radio_button_checked_rounded,
                                          color: AppTokens.success,
                                          size: 28,
                                        ),
                                      ),
                                    if (hasCoords)
                                      Marker(
                                        point: LatLng(lat, lng),
                                        width: 54,
                                        height: 54,
                                        child: const Icon(
                                          Icons.location_on_rounded,
                                          color: AppTokens.danger,
                                          size: 54,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _following
                                    ? AppTokens.success
                                    : AppTokens.warning,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _following
                                  ? "Auto-refresh is ON"
                                  : "Auto-refresh is OFF",
                              style: t.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Last location",
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _InfoRow(
                          label: "Latitude",
                          value: lat?.toString() ?? "—",
                        ),
                        const SizedBox(height: 6),
                        _InfoRow(
                          label: "Longitude",
                          value: lng?.toString() ?? "—",
                        ),
                        const SizedBox(height: 10),
                        _InfoRow(
                          label: "Last seen",
                          value: _user?.lastSeenLocalText ?? "—",
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: hasCoords ? _openGoogleMaps : null,
                            icon: const Icon(Icons.map_rounded),
                            label: const Text("Open in Google Maps"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: t.bodySmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
