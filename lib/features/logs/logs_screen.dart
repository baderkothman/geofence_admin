import "package:flutter/material.dart";
import "../../core/api_client.dart";

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

  Future<void> _fetch({bool initial = false}) async {
    try {
      if (initial) setState(() => _loading = true);

      final data = await _api.getList("/api/logs?userId=${widget.userId}");

      if (!mounted) return;
      setState(() {
        _items = data;
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

  List<dynamic> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;

    return _items
        .where((it) => it.toString().toLowerCase().contains(q))
        .toList();
  }

  ({String title, String subtitle, String? trailing}) _format(dynamic item) {
    // Backend can return a string or a JSON map. We handle both.
    if (item is Map) {
      final m = Map<String, dynamic>.from(item);

      final type = (m["type"] ?? m["event"] ?? m["action"] ?? "Log").toString();
      final message = (m["message"] ?? m["msg"] ?? m["details"] ?? "")
          .toString();

      final at =
          (m["occurred_at"] ?? m["created_at"] ?? m["timestamp"] ?? m["at"])
              ?.toString();
      final where = (m["where"] ?? m["location"] ?? "").toString();

      final subtitleParts = <String>[];
      if (message.trim().isNotEmpty) subtitleParts.add(message.trim());
      if (where.trim().isNotEmpty) subtitleParts.add(where.trim());

      return (
        title: type,
        subtitle: subtitleParts.isEmpty
            ? m.toString()
            : subtitleParts.join("\n"),
        trailing: at?.trim().isEmpty == true ? null : at,
      );
    }

    // default string
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
            // Search header (web-like)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Filter logs",
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: "Search by any text (type, message, time...)",
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
                final it = list[i];
                final f = _format(it);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text("${i + 1}")),
                      title: Text(
                        f.title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(f.subtitle),
                      isThreeLine: f.subtitle.contains("\n"),
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
