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

  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _radius = (widget.user.zoneRadiusM ?? 150).clamp(50, 2000).toDouble();

    _latCtrl = TextEditingController(
      text: widget.user.zoneCenterLat?.toString() ?? "",
    );
    _lngCtrl = TextEditingController(
      text: widget.user.zoneCenterLng?.toString() ?? "",
    );
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  double? get _lat => double.tryParse(_latCtrl.text.trim());
  double? get _lng => double.tryParse(_lngCtrl.text.trim());

  Future<void> _save() async {
    final lat = _lat;
    final lng = _lng;

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Set zone center first (lat/lng).")),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _api.postJson("/api/users/zone", {
        "userId": widget.user.id,
        "lat": lat,
        "lng": lng,
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
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Zone center",
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _latCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: "Latitude",
                    prefixIcon: Icon(Icons.my_location_rounded),
                    // ✅ theme pill input
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _lngCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: "Longitude",
                    prefixIcon: Icon(Icons.my_location_rounded),
                    // ✅ theme pill input
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  "Radius (meters)",
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
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
      ),
    );
  }
}
