import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../detection/payment_watcher.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

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
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: CanvasBackground(
        child: SafeArea(
          child: Column(
            children: [
              const TopBar(title: 'Settings'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxxl),
                  children: [
                    const SectionHeader('Splitwise', top: Space.lg),
                    if (!app.isDemo)
                      SurfaceCard(
                        padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.sm, Space.lg),
                        child: Row(
                          children: [
                            Avatar(app.currentUser?.user.name ?? '?', size: 44),
                            const SizedBox(width: Space.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Connected', style: text.bodySmall?.copyWith(color: t.muted)),
                                  Text(app.currentUser?.user.name ?? '…', style: text.titleMedium),
                                ],
                              ),
                            ),
                            TextButton(onPressed: app.disconnect, child: const Text('Disconnect')),
                          ],
                        ),
                      )
                    else
                      Tray(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Connect your account', style: text.titleMedium),
                            const SizedBox(height: Space.md),
                            const _Step(1, 'On a computer, open secure.splitwise.com/apps'),
                            const _Step(2, 'Register your application — any name and URL'),
                            const _Step(3, 'Create an API key and paste it here'),
                            const SizedBox(height: Space.md),
                            TextField(
                              controller: _key,
                              obscureText: true,
                              autocorrect: false,
                              decoration: InputDecoration(
                                hintText: 'Paste API key',
                                errorText: _error,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: Space.md),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _busy || _key.text.trim().isEmpty ? null : _connect,
                                child: Text(_busy ? 'Checking…' : 'Connect'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SectionHeader('Permissions'),
                    if (!PaymentWatcher.isSupported)
                      Tray(
                        child: Text(
                          'Payment detection and the floating bubble need Android. '
                          'Use Test on the home screen to try the flow here.',
                          style: text.bodyMedium?.copyWith(color: t.muted),
                        ),
                      )
                    else
                      SurfaceCard(
                        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
                        child: Column(
                          children: [
                            _PermissionRow(
                              icon: Icons.notifications_active_outlined,
                              title: 'Payment detection',
                              subtitle: 'Reads bank & UPI notifications',
                              granted: app.detectionGranted,
                              onGrant: app.requestDetection,
                            ),
                            Divider(height: 1, color: t.tray),
                            _PermissionRow(
                              icon: Icons.picture_in_picture_alt_outlined,
                              title: 'Floating bubble',
                              subtitle: 'Asks to split right after you pay',
                              granted: app.bubbleGranted,
                              onGrant: app.requestBubble,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: Space.xxl),
                    Text(
                      'Uses Splitwise\'s self-serve API — for personal use only. '
                      'Your key stays on this phone.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: t.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.label);

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.card, shape: BoxShape.circle),
            child: Text('$number', style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: Space.md),
          Expanded(child: Text(label, style: text.bodyMedium)),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onGrant,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: t.tray, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: t.ink),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                Text(subtitle, style: text.bodySmall?.copyWith(color: t.muted)),
              ],
            ),
          ),
          if (granted)
            Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Icon(Icons.check_circle, color: t.success),
            )
          else
            FilledButton(
              onPressed: onGrant,
              style: FilledButton.styleFrom(minimumSize: const Size(72, 44)),
              child: const Text('Allow'),
            ),
        ],
      ),
    );
  }
}
