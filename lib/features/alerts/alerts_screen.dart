// D:\geofence_project\geofence_admin\lib\features\alerts\alerts_screen.dart

import "dart:async";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

import "../../core/api_client.dart";
import "../../core/config.dart";
import "../../core/theme/app_tokens.dart";
import "../../models/alert_model.dart";

/// Alerts screen showing recent enter/exit events.
///
/// Behavior:
/// - Polls `/api/alerts` periodically.
/// - Maintains a “cleared until” marker in SharedPreferences.
/// - Filters alerts so cleared items do not reappear (even with timezone differences).
/// - Sorts by time descending and limits to latest 50 for performance.
///
/// CSV Export:
/// - `/api/alerts?format=csv` is opened in an external browser/app.
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

  /// Guard to prevent overlapping fetch cycles (useful with fast polling).
  bool _fetching = false;

  /// SharedPreferences key storing the last “clear” time as UTC epoch milliseconds.
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

  /// Parses a backend timestamp string into DateTime when possible.
  ///
  /// Supports:
  /// - ISO strings
  /// - "YYYY-MM-DD HH:MM:SS" (converted to an ISO-like string)
  DateTime? _parseOccurredAt(String s) {
    final raw = s.trim();
    if (raw.isEmpty) return null;

    final d1 = DateTime.tryParse(raw);
    if (d1 != null) return d1;

    final isoLike = raw.contains(" ") ? raw.replaceFirst(" ", "T") : raw;
    final d2 = DateTime.tryParse(isoLike);
    if (d2 != null) return d2;

    return null;
  }

  /// Converts a DateTime to UTC epoch milliseconds.
  int? _toEpochMsUtc(DateTime? dt) {
    if (dt == null) return null;
    return dt.toUtc().millisecondsSinceEpoch;
  }

  Future<int?> _clearedUntilMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_clearedKeyMs);
  }

  Future<void> _setClearedUntilMs(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_clearedKeyMs, ms);
  }

  /// Loads alerts, applies clear-filter, sorts, and updates UI state.
  Future<void> _load({bool initial = false}) async {
    if (_fetching) return;
    _fetching = true;

    try {
      if (initial && mounted) setState(() => _loading = true);

      final raw = await _api.getList("/api/alerts");
      final clearedMs = await _clearedUntilMs();

      final parsed = raw
          .whereType<Map>()
          .map((e) => AlertModel.fromJson(Map<String, dynamic>.from(e)))
          .where((a) {
            // If user never cleared, show everything.
            if (clearedMs == null) return true;

            // If we cannot parse the timestamp, we do NOT show it after a clear,
            // to avoid old/unknown alerts reappearing forever.
            final ts = _toEpochMsUtc(_parseOccurredAt(a.occurredAt));
            if (ts == null) return false;

            return ts > clearedMs;
          })
          .toList();

      // Sort newest first based on parsed timestamps (fallback to 0).
      parsed.sort((a, b) {
        final ta = _toEpochMsUtc(_parseOccurredAt(a.occurredAt)) ?? 0;
        final tb = _toEpochMsUtc(_parseOccurredAt(b.occurredAt)) ?? 0;
        return tb.compareTo(ta);
      });

      // Limit list length to keep rendering snappy.
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

  /// Clears the alert list permanently (from the UI perspective).
  ///
  /// We set clearedUntil to the maximum timestamp currently visible (or now),
  /// ensuring those entries never show again, regardless of timezone formatting.
  Future<void> _clear() async {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    int maxSeenMs = 0;
    for (final a in _alerts) {
      final ms = _toEpochMsUtc(_parseOccurredAt(a.occurredAt));
      if (ms != null && ms > maxSeenMs) maxSeenMs = ms;
    }

    final clearedUntil = (maxSeenMs > nowMs ? maxSeenMs : nowMs) + 1;
    await _setClearedUntilMs(clearedUntil);

    if (!mounted) return;
    setState(() => _alerts = []);
  }

  /// Opens a CSV export for all alerts via external browser/app.
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
