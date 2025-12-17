import "package:flutter/material.dart";
import "../../core/config.dart";

class SettingsScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeMode;

  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.onThemeMode,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _baseUrl;

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController(text: AppConfig.baseUrl);
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    super.dispose();
  }

  Future<void> _saveBaseUrl() async {
    final v = _baseUrl.text.trim();
    if (v.isEmpty) return;

    await AppConfig.setBaseUrl(v);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Base URL saved")));
    setState(() {}); // refresh “Current: …”
  }

  ThemeMode _segmentToMode(int idx) {
    switch (idx) {
      case 0:
        return ThemeMode.light;
      case 1:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  int _modeToSegment(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 0;
      case ThemeMode.dark:
        return 1;
      case ThemeMode.system:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Theme",
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),

                  // Modern, web-like “pill” picker
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text("Light"),
                        icon: Icon(Icons.light_mode_rounded),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text("Dark"),
                        icon: Icon(Icons.dark_mode_rounded),
                      ),
                      ButtonSegment(
                        value: 2,
                        label: Text("System"),
                        icon: Icon(Icons.settings_suggest_rounded),
                      ),
                    ],
                    selected: {_modeToSegment(widget.themeMode)},
                    onSelectionChanged: (set) {
                      final idx = set.first;
                      widget.onThemeMode(_segmentToMode(idx));
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "API Base URL",
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _baseUrl,
                    decoration: const InputDecoration(
                      hintText: "http://192.168.1.xx:3000",
                      prefixIcon: Icon(Icons.link_rounded),
                      // ✅ no OutlineInputBorder override -> uses theme pill input
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saveBaseUrl,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text("Save"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(
                              () => _baseUrl.text = AppConfig.defaultBaseUrl,
                            );
                          },
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text("Reset"),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Text("Current: ${AppConfig.baseUrl}", style: t.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
