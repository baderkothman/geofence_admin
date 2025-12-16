import "dart:async";
import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";
import "../../core/api_client.dart";
import "../../core/config.dart";
import "../../models/user_model.dart";
import "../logs/logs_screen.dart";
import "track_screen.dart";
import "zone_editor_screen.dart";

enum UserSort { name, username, lastSeen, zone, status }

class UsersScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const UsersScreen({super.key, required this.onLogout});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _api = ApiClient();

  List<UserModel> _users = [];
  bool _loading = true;
  String? _error;

  Timer? _timer;

  String _search = "";
  int _rowsPerPage = 10;
  int _page = 0;

  UserSort _sort = UserSort.name;
  bool _asc = true;

  @override
  void initState() {
    super.initState();
    _fetch(initial: true);
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch({bool initial = false}) async {
    try {
      if (initial) setState(() => _loading = true);

      final raw = await _api.getList("/api/users");
      final parsed = raw
          .whereType<Map>()
          .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e)))
          .where((u) => u.role != "admin")
          .toList();

      if (!mounted) return;
      setState(() {
        _users = parsed;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to load users";
        _loading = false;
      });
    }
  }

  List<UserModel> get _filtered {
    final q = _search.trim().toLowerCase();
    final list = q.isEmpty
        ? _users
        : _users.where((u) {
            final name = (u.fullName ?? "").toLowerCase();
            final un = u.username.toLowerCase();
            final c = u.contact.toLowerCase();
            return name.contains(q) || un.contains(q) || c.contains(q);
          }).toList();

    int cmp(UserModel a, UserModel b) {
      switch (_sort) {
        case UserSort.name:
          return (a.fullName ?? a.username).toLowerCase().compareTo(
            (b.fullName ?? b.username).toLowerCase(),
          );
        case UserSort.username:
          return a.username.toLowerCase().compareTo(b.username.toLowerCase());
        case UserSort.lastSeen:
          final ta =
              DateTime.tryParse(a.lastSeen ?? "")?.millisecondsSinceEpoch ?? 0;
          final tb =
              DateTime.tryParse(b.lastSeen ?? "")?.millisecondsSinceEpoch ?? 0;
          return ta.compareTo(tb);
        case UserSort.zone:
          return (a.hasZone ? 1 : 0).compareTo(b.hasZone ? 1 : 0);
        case UserSort.status:
          return (a.isInside ? 1 : 0).compareTo(b.isInside ? 1 : 0);
      }
    }

    list.sort((a, b) => _asc ? cmp(a, b) : cmp(b, a));
    return list;
  }

  List<UserModel> get _paged {
    final total = _filtered.length;
    final start = _page * _rowsPerPage;
    if (start >= total && total > 0) {
      // reset if list shrank
      _page = 0;
    }
    final s = _page * _rowsPerPage;
    final e = (s + _rowsPerPage).clamp(0, total);
    return _filtered.sublist(s, e);
  }

  String _fmtLastSeen(String? iso) {
    if (iso == null) return "Never";
    final d = DateTime.tryParse(iso);
    if (d == null) return "Never";
    return "${d.toLocal()}".split(".").first;
  }

  Future<void> _openCsvForUser(int userId) async {
    final url = "${AppConfig.baseUrl}/api/alerts?userId=$userId&format=csv";
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final total = _filtered.length;
    final start = total == 0 ? 0 : (_page * _rowsPerPage) + 1;
    final end = (_page * _rowsPerPage + _paged.length);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Users"),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: () => _fetch(initial: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: "Logout",
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetch(initial: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            // Search + sort + rows per page
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: "Search name / username / contact",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() {
                        _search = v;
                        _page = 0;
                      }),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<UserSort>(
                            initialValue: _sort,
                            decoration: const InputDecoration(
                              labelText: "Sort",
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: UserSort.name,
                                child: Text("Name"),
                              ),
                              DropdownMenuItem(
                                value: UserSort.username,
                                child: Text("Username"),
                              ),
                              DropdownMenuItem(
                                value: UserSort.lastSeen,
                                child: Text("Last seen"),
                              ),
                              DropdownMenuItem(
                                value: UserSort.zone,
                                child: Text("Zone assigned"),
                              ),
                              DropdownMenuItem(
                                value: UserSort.status,
                                child: Text("Inside/Outside"),
                              ),
                            ],
                            onChanged: (v) => setState(() {
                              _sort = v ?? UserSort.name;
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          tooltip: _asc ? "Ascending" : "Descending",
                          onPressed: () => setState(() => _asc = !_asc),
                          icon: Icon(
                            _asc
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _rowsPerPage,
                            decoration: const InputDecoration(
                              labelText: "Rows",
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 10, child: Text("10")),
                              DropdownMenuItem(value: 15, child: Text("15")),
                              DropdownMenuItem(value: 25, child: Text("25")),
                              DropdownMenuItem(value: 50, child: Text("50")),
                            ],
                            onChanged: (v) => setState(() {
                              _rowsPerPage = v ?? 10;
                              _page = 0;
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: total == 0 || _page == 0
                                ? null
                                : () => setState(() => _page -= 1),
                            icon: const Icon(Icons.chevron_left_rounded),
                            label: const Text("Prev"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: total == 0 || end >= total
                                ? null
                                : () => setState(() => _page += 1),
                            icon: const Icon(Icons.chevron_right_rounded),
                            label: const Text("Next"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        total == 0 ? "0 users" : "$start–$end of $total",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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
                padding: const EdgeInsets.only(top: 24),
                child: Center(child: Text(_error!)),
              )
            else if (total == 0)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: Text("No users yet.")),
              )
            else
              ..._paged.map(
                (u) => _UserCard(
                  user: u,
                  lastSeenText: _fmtLastSeen(u.lastSeen),
                  onZone: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ZoneEditorScreen(user: u),
                      ),
                    );
                    // refresh after closing
                    _fetch();
                  },
                  onTrack: u.hasZone
                      ? () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TrackScreen(
                                userId: u.id,
                                username: u.username,
                              ),
                            ),
                          );
                        }
                      : null,
                  onLogs: u.hasZone
                      ? () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LogsScreen(
                                userId: u.id,
                                username: u.username,
                              ),
                            ),
                          );
                        }
                      : null,
                  onCsv: u.hasZone ? () => _openCsvForUser(u.id) : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final String lastSeenText;
  final VoidCallback onZone;
  final VoidCallback? onTrack;
  final VoidCallback? onLogs;
  final VoidCallback? onCsv;

  const _UserCard({
    required this.user,
    required this.lastSeenText,
    required this.onZone,
    required this.onTrack,
    required this.onLogs,
    required this.onCsv,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final statusColor = !user.hasZone
        ? cs.outline
        : (user.isInside ? Colors.green : Colors.red);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    user.username.isNotEmpty
                        ? user.username[0].toUpperCase()
                        : "?",
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName ?? "—",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "@${user.username} • Last seen: $lastSeenText",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(user.hasZone ? "Zone: Assigned" : "Zone: None"),
                ),
                Chip(
                  label: Text(
                    !user.hasZone
                        ? "Status: —"
                        : (user.isInside ? "Inside" : "Outside"),
                  ),
                ),
                Chip(label: Text("Contact: ${user.contact}")),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onZone,
                  icon: const Icon(Icons.my_location_rounded),
                  label: Text(
                    user.hasZone ? "View / Update Zone" : "Assign Zone",
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onTrack,
                  icon: const Icon(Icons.location_searching_rounded),
                  label: const Text("Track"),
                ),
                OutlinedButton.icon(
                  onPressed: onLogs,
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text("Logs"),
                ),
                OutlinedButton.icon(
                  onPressed: onCsv,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text("CSV"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
