import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:onyx/onyx.dart';

import '../app_controller.dart';
import '../sources/lock_bridge.dart';

/// App lock: covers the app until the phone's fingerprint (or screen lock)
/// is given — on launch, and on coming back after [relockAfter] away. A
/// short trip out (opening Splitwise, picking a backup file) doesn't relock.
class AppLock extends StatefulWidget {
  const AppLock({super.key, required this.controller, required this.child});

  final AppController controller;
  final Widget child;

  static const relockAfter = Duration(seconds: 60);

  /// False while the lock screen is up, so other prompts can wait for it.
  static final open = ValueNotifier(false);

  /// Completes once the app is unlocked (at once if it is).
  static Future<void> whenOpen() {
    if (open.value) return Future.value();
    final done = Completer<void>();
    void listener() {
      if (!open.value) return;
      open.removeListener(listener);
      done.complete();
    }

    open.addListener(listener);
    return done.future;
  }

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  late bool _locked = widget.controller.isAndroid;
  bool _prompting = false;
  DateTime? _awaySince;

  AppController get _app => widget.controller;
  bool get _wanted => _app.isAndroid && _app.appearance.lock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLock.open.value = !_locked;
    if (_locked) _whenSettingsRead(_firstUnlock);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _whenSettingsRead(VoidCallback then) {
    if (_app.settingsRead) return then();
    void listener() {
      if (!_app.settingsRead) return;
      _app.removeListener(listener);
      then();
    }

    _app.addListener(listener);
  }

  Future<void> _firstUnlock() async {
    if (!_wanted || !await LockBridge.available()) return _open();
    await _prompt();
  }

  Future<void> _prompt() async {
    if (_prompting) return;
    _prompting = true;
    final ok = await LockBridge.unlock();
    _prompting = false;
    if (ok) _open();
  }

  void _open() {
    _awaySince = null;
    AppLock.open.value = true;
    if (mounted && _locked) setState(() => _locked = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The unlock sheet itself pauses the app; that isn't leaving it.
    if (_prompting) return;
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _awaySince ??= DateTime.now();
      case AppLifecycleState.resumed:
        final away = _awaySince;
        _awaySince = null;
        if (_locked) {
          unawaited(_prompt());
        } else if (_wanted && away != null && DateTime.now().difference(away) >= AppLock.relockAfter) {
          setState(() => _locked = true);
          AppLock.open.value = false;
          unawaited(_prompt());
        }
      default:
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      // Kept built so state survives, but hidden and inert while locked.
      Offstage(
        offstage: _locked,
        child: TickerMode(enabled: !_locked, child: widget.child),
      ),
      if (_locked) _LockScreen(onUnlock: _prompt),
    ],
  );
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.type;
    return ColoredBox(
      color: c.canvas,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(OSpace.gutter),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: ShapeDecoration(color: c.raised, shape: const CircleBorder()),
                child: Icon(LucideIcons.lockKeyhole, size: 28, color: c.ink),
              ),
              const SizedBox(height: OSpace.xl),
              Text('One Tracker is locked', style: text.title2, textAlign: TextAlign.center),
              const SizedBox(height: OSpace.sm),
              Text('Use your fingerprint or screen lock to open it.', style: text.small, textAlign: TextAlign.center),
              const Spacer(),
              OButton(
                label: 'Unlock',
                icon: LucideIcons.fingerprint,
                size: OButtonSize.lg,
                expand: true,
                onPressed: onUnlock,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
