import "package:flutter/material.dart";
import "../../core/api_client.dart";
import "../../models/user_model.dart";

class ZoneEditorScreen extends StatefulWidget {
  final UserModel user;

  const ZoneEditorScreen({super.key, required this.user});

  @override
  State<ZoneEditorScreen> createState() => _ZoneEditorScreenState();
}

class _ZoneEditorScreenState extends State<ZoneEditorScreen> {
  final _api = ApiClient();

  late double _radius;
  double? _lat;
  double? _lng;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _radius = widget.user.zoneRadiusM ?? 150;
    _lat = widget.user.zoneCenterLat;
    _lng = widget.user.zoneCenterLng;
  }

  Future<void> _save() async {
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Set zone center first (lat/lng).")),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // ✅ change this path if your backend uses another route
      await _api.postJson("/api/users/zone", {
        "userId": widget.user.id,
        "lat": _lat,
        "lng": _lng,
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
    return Scaffold(
      appBar: AppBar(
        title: Text("Zone • ${widget.user.username}"),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const Text("Saving...") : const Text("Save"),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Zone center",
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Latitude"),
                  controller: TextEditingController(
                    text: _lat?.toString() ?? "",
                  ),
                  onChanged: (v) => _lat = double.tryParse(v),
                ),
                const SizedBox(height: 10),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Longitude"),
                  controller: TextEditingController(
                    text: _lng?.toString() ?? "",
                  ),
                  onChanged: (v) => _lng = double.tryParse(v),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Radius (meters)",
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Slider(
                  value: _radius.clamp(50, 2000),
                  min: 50,
                  max: 2000,
                  divisions: 39,
                  label: "${_radius.toStringAsFixed(0)} m",
                  onChanged: (v) => setState(() => _radius = v),
                ),
                Text("Current: ${_radius.toStringAsFixed(0)} m"),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
