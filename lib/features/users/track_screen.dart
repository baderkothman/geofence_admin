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
  final ApiClient _api = ApiClient();
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
          .toList();

      UserModel? u;
      for (final x in users) {
        if (x.id == widget.userId) {
          u = x;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _user = u;
        _error = (u == null) ? "User not found" : null;
        _loading = false;
      });

      // Move map to last location if available, else zone center
      final lat = u?.lastLatitude;
      final lng = u?.lastLongitude;
      final zLat = u?.zoneCenterLat;
      final zLng = u?.zoneCenterLng;

      LatLng? p;
      if (lat != null && lng != null) {
        p = LatLng(lat, lng);
      } else if (zLat != null && zLng != null) {
        p = LatLng(zLat, zLng);
      }

      if (p != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _map.move(p!, _map.camera.zoom < 15 ? 16 : _map.camera.zoom);
          } catch (_) {}
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to refresh location: $e";
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

    final u = _user;

    final lat = u?.lastLatitude;
    final lng = u?.lastLongitude;

    final zLat = u?.zoneCenterLat;
    final zLng = u?.zoneCenterLng;
    final zR = u?.zoneRadiusM;

    final fallback = const LatLng(33.8938, 35.5018);
    final center = (lat != null && lng != null)
        ? LatLng(lat, lng)
        : ((zLat != null && zLng != null) ? LatLng(zLat, zLng) : fallback);

    final followingColor = _following ? AppTokens.success : AppTokens.warning;

    return Scaffold(
      appBar: AppBar(
        title: Text("Track • ${widget.username}"),
        actions: [
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
          : Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppTokens.radius),
                          child: FlutterMap(
                            mapController: _map,
                            options: MapOptions(
                              initialCenter: center,
                              initialZoom: (lat != null && lng != null)
                                  ? 16
                                  : 13,
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

                              if (zLat != null && zLng != null && zR != null)
                                CircleLayer(
                                  circles: [
                                    CircleMarker(
                                      point: LatLng(zLat, zLng),
                                      radius: zR,
                                      useRadiusInMeter: true,
                                      color: AppTokens.success.withAlpha(30),
                                      borderStrokeWidth: 2,
                                      borderColor: AppTokens.success.withAlpha(
                                        170,
                                      ),
                                    ),
                                  ],
                                ),

                              MarkerLayer(
                                markers: [
                                  if (zLat != null && zLng != null)
                                    Marker(
                                      point: LatLng(zLat, zLng),
                                      width: 44,
                                      height: 44,
                                      child: const Icon(
                                        Icons.radio_button_checked_rounded,
                                        color: AppTokens.success,
                                        size: 28,
                                      ),
                                    ),
                                  if (lat != null && lng != null)
                                    Marker(
                                      point: LatLng(lat, lng),
                                      width: 54,
                                      height: 54,
                                      child: Icon(
                                        Icons.location_on_rounded,
                                        color: u?.isInside == true
                                            ? AppTokens.success
                                            : AppTokens.danger,
                                        size: 54,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
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
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: followingColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _following
                                    ? "Auto-refresh is ON"
                                    : "Auto-refresh is OFF",
                                style: t.bodySmall,
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () =>
                                    setState(() => _following = !_following),
                                icon: Icon(
                                  _following ? Icons.gps_fixed : Icons.gps_off,
                                ),
                                label: Text(
                                  _following ? "Following" : "Paused",
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(
                                child: _InfoRow(
                                  label: "Lat",
                                  value: lat?.toString() ?? "—",
                                ),
                              ),
                              Expanded(
                                child: _InfoRow(
                                  label: "Lng",
                                  value: lng?.toString() ?? "—",
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _InfoRow(
                            label: "Last seen",
                            value: u?.lastSeenLocalText ?? "Never",
                          ),
                          const SizedBox(height: 6),
                          _InfoRow(
                            label: "Inside",
                            value: u == null
                                ? "—"
                                : (u.isInside ? "Yes" : "No"),
                          ),

                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: (lat != null && lng != null)
                                  ? _openGoogleMaps
                                  : null,
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
          width: 72,
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
