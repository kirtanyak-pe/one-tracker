import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../detection/payment_watcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _key = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).connect(_key.text);
      _key.clear();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Splitwise', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (!app.isDemo) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline),
              title: Text('Connected as ${app.currentUser?.user.name ?? '…'}'),
              trailing: TextButton(onPressed: app.disconnect, child: const Text('Disconnect')),
            ),
          ] else ...[
            Text(
              'Get a personal API key: on the web, open secure.splitwise.com/apps → '
              'Register your application (any name and URL) → copy the API key.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _key,
              obscureText: true,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Splitwise API key',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy || _key.text.trim().isEmpty ? null : _connect,
              child: Text(_busy ? 'Checking…' : 'Connect'),
            ),
          ],
          const SizedBox(height: 32),
          Text('Permissions', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (!PaymentWatcher.isSupported)
            Text(
              'Payment detection and the floating bubble need Android. '
              'Use ⚡ on the home screen to try the flow here.',
              style: theme.textTheme.bodyMedium,
            )
          else ...[
            _PermissionTile(
              title: 'Payment detection',
              subtitle: 'Notification access, to spot bank & UPI payments',
              granted: app.detectionGranted,
              onGrant: app.requestDetection,
            ),
            _PermissionTile(
              title: 'Floating bubble',
              subtitle: 'Display over other apps, to ask right after you pay',
              granted: app.bubbleGranted,
              onGrant: app.requestBubble,
            ),
          ],
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onGrant,
  });

  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: granted
            ? const Icon(Icons.check_circle_outline)
            : FilledButton.tonal(onPressed: onGrant, child: const Text('Allow')),
      );
}
