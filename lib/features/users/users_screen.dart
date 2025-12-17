import "dart:async";
import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";
import "../../core/api_client.dart";
import "../../core/config.dart";
import "../../core/theme/app_tokens.dart";
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
    } catch (_) {
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
            final name = u.displayName.toLowerCase();
            final un = u.username.toLowerCase();
            final c = u.contact.toLowerCase();
            return name.contains(q) || un.contains(q) || c.contains(q);
          }).toList();

    int cmp(UserModel a, UserModel b) {
      switch (_sort) {
        case UserSort.name:
          return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
        case UserSort.username:
          return a.username.toLowerCase().compareTo(b.username.toLowerCase());
        case UserSort.lastSeen:
          final ta = a.lastSeenDate?.millisecondsSinceEpoch ?? 0;
          final tb = b.lastSeenDate?.millisecondsSinceEpoch ?? 0;
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
    if (start >= total && total > 0) _page = 0;

    final s = _page * _rowsPerPage;
    final e = (s + _rowsPerPage).clamp(0, total);
    return _filtered.sublist(s, e);
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: "Search name / username / contact",
                        // ✅ no border override -> uses your pill InputDecorationTheme
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
                              // ✅ no border override
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
                              // ✅ no border override
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
                  onZone: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ZoneEditorScreen(user: u),
                      ),
                    );
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
  final VoidCallback onZone;
  final VoidCallback? onTrack;
  final VoidCallback? onLogs;
  final VoidCallback? onCsv;

  const _UserCard({
    required this.user,
    required this.onZone,
    required this.onTrack,
    required this.onLogs,
    required this.onCsv,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final border = Theme.of(context).dividerColor;

    final statusColor = !user.hasZone
        ? border
        : (user.isInside ? AppTokens.success : AppTokens.danger);

    final zoneBtnStyle = FilledButton.styleFrom(
      backgroundColor: AppTokens.success,
      foregroundColor: Colors.white,
    );

    final trackBtnStyle = FilledButton.styleFrom(
      backgroundColor: AppTokens.danger,
      foregroundColor: Colors.white,
    );

    final csvBtnStyle = FilledButton.styleFrom(
      backgroundColor: AppTokens.warning,
      foregroundColor: const Color(0xFF3B2A00),
    );

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
                  backgroundColor: cs.primary.withAlpha(36),
                  foregroundColor: cs.primary,
                  child: Text(
                    user.username.isNotEmpty
                        ? user.username[0].toUpperCase()
                        : "?",
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "@${user.username} • Last seen: ${user.lastSeenLocalText}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall,
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
                  style: zoneBtnStyle,
                  onPressed: onZone,
                  icon: const Icon(Icons.my_location_rounded),
                  label: Text(
                    user.hasZone ? "View / Update Zone" : "Assign Zone",
                  ),
                ),
                FilledButton.icon(
                  style: trackBtnStyle,
                  onPressed: onTrack,
                  icon: const Icon(Icons.location_searching_rounded),
                  label: const Text("Track"),
                ),
                OutlinedButton.icon(
                  onPressed: onLogs,
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text("Logs"),
                ),
                FilledButton.icon(
                  style: csvBtnStyle,
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
