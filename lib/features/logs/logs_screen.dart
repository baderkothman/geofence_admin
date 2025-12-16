import "dart:async";
import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";
import "../../core/api_client.dart";
import "../../core/config.dart";
import "../../models/alert_model.dart";

class LogsScreen extends StatefulWidget {
  final int userId;
  final String? username;

  const LogsScreen({super.key, required this.userId, this.username});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _api = ApiClient();
  Timer? _timer;

  List<AlertModel> _logs = [];
  bool _loading = true;
  String? _error;

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

  Future<void> _load({bool initial = false}) async {
    try {
      if (initial) setState(() => _loading = true);

      final raw = await _api.getList("/api/alerts?userId=${widget.userId}");
      final list = raw
          .whereType<Map>()
          .map((e) => AlertModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      list.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

      if (!mounted) return;
      setState(() {
        _logs = list;
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to load logs";
        _loading = false;
      });
    }
  }

  Future<void> _downloadCsv() async {
    final url =
        "${AppConfig.baseUrl}/api/alerts?userId=${widget.userId}&format=csv";
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.username == null
        ? "Logs"
        : "Logs • ${widget.username}";

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: "Download CSV",
            onPressed: _downloadCsv,
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
          : _error != null
          ? Center(child: Text(_error!))
          : _logs.isEmpty
          ? const Center(child: Text("No logs yet."))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final a = _logs[i];
                final dt = DateTime.tryParse(a.occurredAt)?.toLocal();
                final timeText = dt == null
                    ? a.occurredAt
                    : "$dt".split(".").first;

                return Card(
                  child: ListTile(
                    leading: Icon(
                      a.isEnter ? Icons.login_rounded : Icons.logout_rounded,
                      color: a.isEnter ? Colors.green : Colors.red,
                    ),
                    title: Text(a.isEnter ? "Entered" : "Exited"),
                    subtitle: Text(timeText),
                  ),
                );
              },
            ),
    );
  }
}
