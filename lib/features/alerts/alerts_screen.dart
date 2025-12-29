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

  bool _fetching = false;

  // ✅ store as epoch ms (more reliable than strings/timezones)
  static const _clearedKeyMs = "alerts_cleared_until_ms";

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

  DateTime? _parseOccurredAt(String s) {
    final raw = s.trim();
    if (raw.isEmpty) return null;

    // 1) Try normal parse (handles ISO, and many formats)
    final d1 = DateTime.tryParse(raw);
    if (d1 != null) return d1;

    // 2) Common backend format: "YYYY-MM-DD HH:MM:SS"
    // Convert to ISO-ish: "YYYY-MM-DDTHH:MM:SS"
    final isoLike = raw.contains(" ") ? raw.replaceFirst(" ", "T") : raw;
    final d2 = DateTime.tryParse(isoLike);
    if (d2 != null) return d2;

    return null;
  }

  int? _toEpochMsUtc(DateTime? dt) {
    if (dt == null) return null;
    return dt.toUtc().millisecondsSinceEpoch;
  }

  Future<int?> _clearedUntilMs() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_clearedKeyMs);
    return ms;
  }

  Future<void> _setClearedUntilMs(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_clearedKeyMs, ms);
  }

  Future<void> _load({bool initial = false}) async {
    if (_fetching) return;
    _fetching = true;

    try {
      if (initial && mounted) setState(() => _loading = true);

      final raw = await _api.getList("/api/alerts");

      final clearedMs = await _clearedUntilMs();

      // Parse + filter
      final parsed = raw
          .whereType<Map>()
          .map((e) => AlertModel.fromJson(Map<String, dynamic>.from(e)))
          .where((a) {
            if (clearedMs == null) return true;

            final dt = _parseOccurredAt(a.occurredAt);
            final ts = _toEpochMsUtc(dt);

            // ✅ IMPORTANT:
            // If we cannot parse the time AND user cleared before,
            // we hide it (this prevents "coming back" forever).
            if (ts == null) return false;

            return ts > clearedMs;
          })
          .toList();

      // Sort by real time (fallback: keep stable)
      parsed.sort((a, b) {
        final ta = _toEpochMsUtc(_parseOccurredAt(a.occurredAt)) ?? 0;
        final tb = _toEpochMsUtc(_parseOccurredAt(b.occurredAt)) ?? 0;
        return tb.compareTo(ta);
      });

      final list = (parsed.length > 50) ? parsed.sublist(0, 50) : parsed;

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
    } finally {
      _fetching = false;
    }
  }

  Future<void> _clear() async {
    // ✅ Make "clear" bulletproof:
    // set clearedUntil to the MAX occurredAt we currently have (or now),
    // so these alerts can never show again even with timezone differences.
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    int maxSeenMs = 0;
    for (final a in _alerts) {
      final dt = _parseOccurredAt(a.occurredAt);
      final ms = _toEpochMsUtc(dt);
      if (ms != null && ms > maxSeenMs) maxSeenMs = ms;
    }

    final clearedUntil = (maxSeenMs > nowMs ? maxSeenMs : nowMs) + 1;
    await _setClearedUntilMs(clearedUntil);

    if (!mounted) return;
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

                final dt = _parseOccurredAt(a.occurredAt)?.toLocal();
                final timeText = dt == null
                    ? a.occurredAt
                    : dt.toString().split(".").first;

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
