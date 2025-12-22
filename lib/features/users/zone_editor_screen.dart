import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";

import "../../core/api_client.dart";
import "../../core/theme/app_tokens.dart";
import "../../models/user_model.dart";

class ZoneEditorScreen extends StatefulWidget {
  final UserModel user;

  const ZoneEditorScreen({super.key, required this.user});

  @override
  State<ZoneEditorScreen> createState() => _ZoneEditorScreenState();
}

class _ZoneEditorScreenState extends State<ZoneEditorScreen> {
  final _api = ApiClient();
  final MapController _map = MapController();

  late double _radius;
  LatLng? _center;

  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;

  bool _saving = false;
  bool _typing = false;

  @override
  void initState() {
    super.initState();

    _radius = (widget.user.zoneRadiusM ?? 150).clamp(50, 2000).toDouble();

    final initLat = widget.user.zoneCenterLat;
    final initLng = widget.user.zoneCenterLng;

    _latCtrl = TextEditingController(text: initLat?.toString() ?? "");
    _lngCtrl = TextEditingController(text: initLng?.toString() ?? "");

    if (initLat != null && initLng != null) {
      _center = LatLng(initLat, initLng);
    }
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  double? get _lat => double.tryParse(_latCtrl.text.trim());
  double? get _lng => double.tryParse(_lngCtrl.text.trim());

  void _setCenter(LatLng p, {bool moveMap = true}) {
    setState(() => _center = p);

    _typing = true;
    _latCtrl.text = p.latitude.toStringAsFixed(6);
    _lngCtrl.text = p.longitude.toStringAsFixed(6);
    _typing = false;

    if (moveMap) {
      try {
        _map.move(p, _map.camera.zoom < 15 ? 16 : _map.camera.zoom);
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final c = _center;
    if (c == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tap the map to set zone center first.")),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _api.postJson("/api/users/zone", {
        "userId": widget.user.id,
        "lat": c.latitude,
        "lng": c.longitude,
        "radiusM": _radius,
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to save zone")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final fallback = const LatLng(33.8938, 35.5018); // Beirut
    final center = _center ?? fallback;

    return Scaffold(
      appBar: AppBar(
        title: Text("Zone • ${widget.user.username}"),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_saving ? "Saving..." : "Save"),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Zone map",
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Tap anywhere to set the zone center.",
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
                          initialZoom: _center == null ? 13 : 16,
                          onTap: (tapPos, point) => _setCenter(point),
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
                          if (_center != null)
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: _center!,
                                  radius: _radius,
                                  useRadiusInMeter: true,
                                  color: AppTokens.success.withAlpha(30),
                                  borderStrokeWidth: 2,
                                  borderColor: AppTokens.success.withAlpha(170),
                                ),
                              ],
                            ),
                          if (_center != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _center!,
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
                    "Zone center",
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _latCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    onChanged: (_) {
                      if (_typing) return;
                      final lat = _lat;
                      final lng = _lng;
                      if (lat == null || lng == null) return;
                      _setCenter(LatLng(lat, lng));
                    },
                    decoration: const InputDecoration(
                      labelText: "Latitude",
                      prefixIcon: Icon(Icons.my_location_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _lngCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    onChanged: (_) {
                      if (_typing) return;
                      final lat = _lat;
                      final lng = _lng;
                      if (lat == null || lng == null) return;
                      _setCenter(LatLng(lat, lng));
                    },
                    decoration: const InputDecoration(
                      labelText: "Longitude",
                      prefixIcon: Icon(Icons.my_location_rounded),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    "Radius (meters)",
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Current: ${_radius.toStringAsFixed(0)} m",
                    style: t.bodySmall,
                  ),
                  Slider(
                    value: _radius,
                    min: 50,
                    max: 2000,
                    divisions: 39,
                    label: "${_radius.toStringAsFixed(0)} m",
                    onChanged: (v) => setState(() => _radius = v),
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
