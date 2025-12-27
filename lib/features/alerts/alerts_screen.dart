import "dart:async";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";
import "../../core/api_client.dart";
import "../../core/config.dart";
import "../../core/theme/app_tokens.dart";
import "../../models/alert_model.dart";

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _api = ApiClient();
  Timer? _timer;

  List<AlertModel> _alerts = [];
  bool _loading = true;
  String? _error;

  static const _clearedKey = "alerts_cleared_until";

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<DateTime?> _clearedUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_clearedKey);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  Future<void> _setClearedNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _clearedKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<void> _load({bool initial = false}) async {
    try {
      if (initial) setState(() => _loading = true);

      final raw = await _api.getList("/api/alerts");
      var list = raw
          .whereType<Map>()
          .map((e) => AlertModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final cleared = await _clearedUntil();
      if (cleared != null) {
        list = list.where((a) {
          final dt = DateTime.tryParse(a.occurredAt);
          if (dt == null) return true;
          return dt.isAfter(cleared);
        }).toList();
      }

      list.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      if (list.length > 50) list = list.sublist(0, 50);

      if (!mounted) return;
      setState(() {
        _alerts = list;
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to load alerts";
        _loading = false;
      });
    }
  }

  Future<void> _clear() async {
    await _setClearedNow();
    setState(() => _alerts = []);
  }

  Future<void> _downloadAllCsv() async {
    final url = "${AppConfig.baseUrl}/api/alerts?format=csv";
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Alerts"),
        actions: [
          IconButton(
            tooltip: "Clear",
            onPressed: _alerts.isEmpty ? null : _clear,
            icon: const Icon(Icons.clear_all_rounded),
          ),
          IconButton(
            tooltip: "Download all CSV",
            onPressed: _downloadAllCsv,
            icon: const Icon(Icons.download_rounded),
          ),
          IconButton(
            tooltip: "Refresh",
            onPressed: () => _load(initial: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? Center(child: Text(_error!))
          : (_alerts.isEmpty)
          ? const Center(child: Text("No alerts after last clear."))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _alerts.length,
              separatorBuilder: (context, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final a = _alerts[i];
                final dt = DateTime.tryParse(a.occurredAt)?.toLocal();
                final timeText = dt == null
                    ? a.occurredAt
                    : "$dt".split(".").first;
                final who = a.username ?? "User #${a.userId}";

                final color = a.isEnter ? AppTokens.success : AppTokens.danger;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withAlpha(28),
                      foregroundColor: color,
                      child: Icon(
                        a.isEnter ? Icons.login_rounded : Icons.logout_rounded,
                      ),
                    ),
                    title: Text(a.isEnter ? "Entered zone" : "Left zone"),
                    subtitle: Text("$who\n$timeText"),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}
