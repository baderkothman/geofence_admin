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

enum ZoneFilter { all, assigned, none }

enum StatusFilter { all, inside, outside }

class UsersScreen extends StatefulWidget {
  final VoidCallback onLogout;

  // ✅ add theme toggle hooks here
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeMode;

  const UsersScreen({
    super.key,
    required this.onLogout,
    required this.themeMode,
    required this.onThemeMode,
  });

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _api = ApiClient();
  Timer? _timer;

  List<UserModel> _users = [];
  bool _loading = true;
  String? _error;

  String _search = "";
  ZoneFilter _zoneFilter = ZoneFilter.all;
  StatusFilter _statusFilter = StatusFilter.all;

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
    Iterable<UserModel> list = _users;

    if (q.isNotEmpty) {
      list = list.where((u) {
        final name = u.displayName.toLowerCase();
        final un = u.username.toLowerCase();
        final c = u.contact.toLowerCase();
        return name.contains(q) || un.contains(q) || c.contains(q);
      });
    }

    if (_zoneFilter == ZoneFilter.assigned) {
      list = list.where((u) => u.hasZone);
    } else if (_zoneFilter == ZoneFilter.none) {
      list = list.where((u) => !u.hasZone);
    }

    if (_statusFilter == StatusFilter.inside) {
      list = list.where((u) => u.hasZone && u.isInside);
    } else if (_statusFilter == StatusFilter.outside) {
      list = list.where((u) => u.hasZone && !u.isInside);
    }

    int rank(UserModel u) {
      if (!u.hasZone) return 0;
      if (!u.isInside) return 1;
      return 2;
    }

    final out = list.toList()
      ..sort((a, b) {
        final ra = rank(a);
        final rb = rank(b);
        if (ra != rb) return ra.compareTo(rb);
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      });

    return out;
  }

  Future<void> _openCsvForUser(int userId) async {
    final url = "${AppConfig.baseUrl}/api/alerts?userId=$userId&format=csv";
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  // ✅ one-tap theme toggle (no popup)
  Future<void> _toggleTheme() async {
    final isDark = widget.themeMode == ThemeMode.dark;
    final next = isDark ? ThemeMode.light : ThemeMode.dark;
    await widget.onThemeMode(next);
    if (!mounted) return;
    setState(() {}); // harmless; ensures icon updates instantly
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final list = _filtered;

    final assignedCount = _users.where((u) => u.hasZone).length;
    final noneCount = _users.length - assignedCount;
    final insideCount = _users.where((u) => u.hasZone && u.isInside).length;
    final outsideCount = _users.where((u) => u.hasZone && !u.isInside).length;

    final isDark = widget.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Users"),
        actions: [
          // ✅ nicer single button: tap toggles immediately
          IconButton(
            tooltip: isDark ? "Switch to Light" : "Switch to Dark",
            onPressed: _toggleTheme,
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Filter users",
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: "Search name / username / contact",
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                tooltip: "Clear",
                                onPressed: () => setState(() => _search = ""),
                                icon: const Icon(Icons.clear_rounded),
                              ),
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "Zone",
                      style: t.bodySmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ChoiceChip(
                          selected: _zoneFilter == ZoneFilter.all,
                          label: "All (${_users.length})",
                          onTap: () =>
                              setState(() => _zoneFilter = ZoneFilter.all),
                        ),
                        _ChoiceChip(
                          selected: _zoneFilter == ZoneFilter.assigned,
                          label: "Assigned ($assignedCount)",
                          onTap: () =>
                              setState(() => _zoneFilter = ZoneFilter.assigned),
                        ),
                        _ChoiceChip(
                          selected: _zoneFilter == ZoneFilter.none,
                          label: "No zone ($noneCount)",
                          onTap: () =>
                              setState(() => _zoneFilter = ZoneFilter.none),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "Status",
                      style: t.bodySmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ChoiceChip(
                          selected: _statusFilter == StatusFilter.all,
                          label: "All",
                          onTap: () =>
                              setState(() => _statusFilter = StatusFilter.all),
                        ),
                        _ChoiceChip(
                          selected: _statusFilter == StatusFilter.inside,
                          label: "Inside ($insideCount)",
                          onTap: () => setState(
                            () => _statusFilter = StatusFilter.inside,
                          ),
                          color: AppTokens.success,
                        ),
                        _ChoiceChip(
                          selected: _statusFilter == StatusFilter.outside,
                          label: "Outside ($outsideCount)",
                          onTap: () => setState(
                            () => _statusFilter = StatusFilter.outside,
                          ),
                          color: AppTokens.danger,
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Text(
                      "Showing ${list.length} of ${_users.length}",
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
                padding: const EdgeInsets.only(top: 24),
                child: Center(child: Text(_error!)),
              )
            else if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: Text("No users match your filters.")),
              )
            else
              ...list.map(
                (u) => _ExpandableUserCard(
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

class _ChoiceChip extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ChoiceChip({
    required this.selected,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bg = selected
        ? (color ?? cs.primary).withAlpha(34)
        : cs.surface.withAlpha(18);

    final fg = selected ? (color ?? cs.primary) : cs.onSurface.withAlpha(220);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? (color ?? cs.primary).withAlpha(120)
                : Theme.of(context).dividerColor.withAlpha(120),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: fg,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// keep your _ExpandableUserCard as-is (unchanged)
class _ExpandableUserCard extends StatefulWidget {
  final UserModel user;
  final VoidCallback onZone;
  final VoidCallback? onTrack;
  final VoidCallback? onLogs;
  final VoidCallback? onCsv;

  const _ExpandableUserCard({
    required this.user,
    required this.onZone,
    required this.onTrack,
    required this.onLogs,
    required this.onCsv,
  });

  @override
  State<_ExpandableUserCard> createState() => _ExpandableUserCardState();
}

class _ExpandableUserCardState extends State<_ExpandableUserCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final border = Theme.of(context).dividerColor;

    final u = widget.user;

    final statusColor = !u.hasZone
        ? border
        : (u.isInside ? AppTokens.success : AppTokens.danger);

    final statusText = !u.hasZone
        ? "No zone"
        : (u.isInside ? "Inside" : "Outside");

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: cs.primary.withAlpha(36),
                    foregroundColor: cs.primary,
                    child: Text(
                      u.username.isNotEmpty ? u.username[0].toUpperCase() : "?",
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "@${u.username} • ${u.contact}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: t.bodySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Icon(
                        _open
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill("Last seen: ${u.lastSeenLocalText}"),
                      _pill(u.hasZone ? "Zone: Assigned" : "Zone: None"),
                      _pill(
                        !u.hasZone
                            ? "Status: —"
                            : "Status: ${u.isInside ? "Inside" : "Outside"}",
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTokens.success,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: widget.onZone,
                        icon: const Icon(Icons.my_location_rounded),
                        label: Text(
                          u.hasZone ? "View / Update Zone" : "Assign Zone",
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTokens.danger,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: widget.onTrack,
                        icon: const Icon(Icons.location_searching_rounded),
                        label: const Text("Track"),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onLogs,
                        icon: const Icon(Icons.receipt_long_rounded),
                        label: const Text("Logs"),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTokens.warning,
                          foregroundColor: const Color(0xFF3B2A00),
                        ),
                        onPressed: widget.onCsv,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text("CSV"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withAlpha(18)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}
