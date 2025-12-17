import "dart:async";
import "package:flutter/material.dart";
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
  Timer? _timer;

  UserModel? _user;
  bool _loading = true;
  bool _following = true; // ✅ now actually controls auto refresh
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
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

      final u = users
          .where((x) => x.id == widget.userId)
          .cast<UserModel?>()
          .first;

      if (!mounted) return;
      setState(() {
        _user = u;
        _error = null;
        _loading = false;
      });
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

    return Scaffold(
      appBar: AppBar(
        title: Text("Track • ${widget.username}"),
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() => _following = !_following);
            },
            icon: Icon(_following ? Icons.gps_fixed : Icons.gps_off),
            label: Text(_following ? "Following" : "Not following"),
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
          : Padding(
              padding: const EdgeInsets.all(14),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Last location",
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
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
                        value: _user?.lastSeen ?? "—",
                      ),

                      const Spacer(),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: hasCoords ? _openGoogleMaps : null,
                          icon: const Icon(Icons.map_rounded),
                          label: const Text("Open in Google Maps"),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Small status hint like web UI
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
            style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
