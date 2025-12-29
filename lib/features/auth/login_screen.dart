// D:\geofence_project\geofence_admin\lib\features\auth\login_screen.dart

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/api_client.dart";
import "../../core/config.dart";
import "../../core/prefs.dart";

/// Admin login screen.
///
/// Calls `/api/login` with username/password, then:
/// - if success => sets UI auth state to true (persisted)
/// - cookies are captured automatically by ApiClient and stored in prefs
///
/// The UI also displays current API Base URL for quick debugging.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _api = ApiClient();
  final _u = TextEditingController();
  final _p = TextEditingController();

  bool _loading = false;
  String? _error;

  /// Attempts login against the backend.
  ///
  /// Expected response shape:
  /// - `{ "success": true }` on success
  /// - non-2xx with JSON body on failure (ApiClient throws)
  Future<void> _login() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _api.postJson("/api/login", {
        "username": _u.text.trim(),
        "password": _p.text,
      });

      final ok = res["success"] == true;
      final msg = (res["message"] is String) ? res["message"] as String : null;

      if (!ok) {
        setState(() {
          _error = msg ?? "Login failed. Invalid username or password.";
        });
        return;
      }

      // Marks UI as authed; bootstrap logic also verifies cookie existence on next launch.
      await setAuthed(ref, true);
    } catch (e) {
      setState(() {
        _error = "Login failed: ${e.toString()}";
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _u.dispose();
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    "Admin Login",
                    style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Sign in to manage users, zones, and alerts.",
                    textAlign: TextAlign.center,
                    style: t.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "API: ${AppConfig.baseUrl}",
                    textAlign: TextAlign.center,
                    style: t.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _u,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: "Username",
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _p,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _loading ? null : _login(),
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _login,
                      icon: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login_rounded),
                      label: Text(_loading ? "Signing in..." : "Login"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
