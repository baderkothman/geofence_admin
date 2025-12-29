// D:\geofence_project\geofence_admin\lib\features\logs\logs_screen.dart

import "package:flutter/material.dart";
import "../../core/api_client.dart";

/// Logs screen for a specific user.
///
/// This screen is intentionally flexible:
/// - Primary source: `/api/alerts?userId=...` (matches your web dashboard usage)
/// - Optional fallback: `/api/logs?userId=...` if your backend provides it
///
/// The UI supports:
/// - Refresh
/// - Free-text search across any serialized content
/// - Adaptive formatting for “alert-like” rows and generic logs
class LogsScreen extends StatefulWidget {
  final int userId;
  final String username;

  const LogsScreen({super.key, required this.userId, required this.username});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _api = ApiClient();

  bool _loading = true;
  String? _error;

  List<dynamic> _items = const [];
  String _query = "";

  @override
  void initState() {
    super.initState();
    _fetch(initial: true);
  }

  /// Fetches a list response for endpoints that are expected to return arrays.
  ///
  /// If in the future some endpoint returns `{ data: [...] }` or `{ rows: [...] }`,
  /// you can extend this helper without changing ApiClient.
  Future<List<dynamic>> _getListFlexible(String path) async {
    return _api.getList(path);
  }

  /// Loads logs for this user.
  ///
  /// Attempts alerts endpoint first, then falls back to logs endpoint.
  Future<void> _fetch({bool initial = false}) async {
    try {
      if (initial) setState(() => _loading = true);

      List<dynamic> data;
      try {
        data = await _getListFlexible("/api/alerts?userId=${widget.userId}");
      } catch (_) {
        data = await _getListFlexible("/api/logs?userId=${widget.userId}");
      }

      if (!mounted) return;
      setState(() {
        _items = data;
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            "Failed to load logs. (Tried /api/alerts and /api/logs for this user)";
        _loading = false;
      });
    }
  }

  /// Applies a simple free-text filter across the serialized item.
  List<dynamic> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;

    return _items
        .where((it) => it.toString().toLowerCase().contains(q))
        .toList();
  }

  /// Formats an item into title/subtitle/trailing UI parts.
  ///
  /// Handles:
  /// - alert objects with `{ alert_type, occurred_at, username, ... }`
  /// - generic logs with `{ type/message/created_at/... }`
  ({String title, String subtitle, String? trailing}) _format(dynamic item) {
    if (item is Map) {
      final m = Map<String, dynamic>.from(item);

      final alertType = (m["alert_type"] ?? "").toString().toLowerCase();
      final isEnter = alertType == "enter";
      final isExit = alertType == "exit";

      if (isEnter || isExit) {
        final who =
            (m["username"] ?? m["user"] ?? "User #${m["user_id"] ?? "?"}")
                .toString();
        final at = (m["occurred_at"] ?? m["created_at"] ?? m["at"])?.toString();
        return (
          title: isEnter ? "Entered zone" : "Left zone",
          subtitle: who,
          trailing: at,
        );
      }

      final type = (m["type"] ?? m["event"] ?? m["action"] ?? "Log").toString();
      final message = (m["message"] ?? m["msg"] ?? m["details"] ?? "")
          .toString();
      final at =
          (m["occurred_at"] ?? m["created_at"] ?? m["timestamp"] ?? m["at"])
              ?.toString();

      return (
        title: type,
        subtitle: message.trim().isEmpty ? m.toString() : message,
        trailing: (at?.trim().isEmpty ?? true) ? null : at,
      );
    }

    final s = item.toString();
    return (title: "Log", subtitle: s, trailing: null);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final list = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: Text("Logs • ${widget.username}"),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: () => _fetch(initial: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetch(initial: true),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Filter logs",
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: "Search by any text (type, user, time...)",
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: "Clear",
                                onPressed: () => setState(() => _query = ""),
                                icon: const Icon(Icons.clear_rounded),
                              ),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Showing ${list.length} of ${_items.length}",
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Center(child: Text(_error!)),
              )
            else if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Center(child: Text("No logs yet.")),
              )
            else
              ...List.generate(list.length, (i) {
                final f = _format(list[i]);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text("${i + 1}")),
                      title: Text(
                        f.title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(f.subtitle),
                      trailing: f.trailing == null
                          ? null
                          : Text(
                              f.trailing!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
