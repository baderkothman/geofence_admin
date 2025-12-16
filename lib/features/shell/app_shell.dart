import "package:flutter/material.dart";
import "../users/users_screen.dart";
import "../alerts/alerts_screen.dart";
import "../settings/settings_screen.dart";

class AppShell extends StatefulWidget {
  final VoidCallback onLogout;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeMode;

  const AppShell({
    super.key,
    required this.onLogout,
    required this.themeMode,
    required this.onThemeMode,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      UsersScreen(onLogout: widget.onLogout),
      const AlertsScreen(),
      SettingsScreen(
        themeMode: widget.themeMode,
        onThemeMode: widget.onThemeMode,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (v) => setState(() => _index = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_alt_rounded),
            label: "Users",
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_active_rounded),
            label: "Alerts",
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}
