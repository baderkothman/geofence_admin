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
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    "Theme",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    groupValue: widget.themeMode,
                    onChanged: (v) => widget.onThemeMode(v!),
                    title: const Text("Light"),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    groupValue: widget.themeMode,
                    onChanged: (v) => widget.onThemeMode(v!),
                    title: const Text("Dark"),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    groupValue: widget.themeMode,
                    onChanged: (v) => widget.onThemeMode(v!),
                    title: const Text("System"),
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
                  const Text(
                    "API Base URL",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _baseUrl,
                    decoration: const InputDecoration(
                      hintText: "http://192.168.1.xx:3000",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _saveBaseUrl,
                          child: const Text("Save"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(
                              () => _baseUrl.text = AppConfig.defaultBaseUrl,
                            );
                          },
                          child: const Text("Reset"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Current: ${AppConfig.baseUrl}",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
