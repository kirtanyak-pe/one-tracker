import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../money.dart';
import '../splitwise/models.dart';
import '../splitwise/splitwise_api.dart';
import '../storage/app_store.dart';
import '../ui/theme.dart';
import '../ui/tokens.dart';
import 'split_card.dart';
import 'split_models.dart';
import 'split_service.dart';

/// Main-app side: permission and opening the floating card.
abstract final class SplitOverlay {
  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> hasPermission() async => isSupported && await FlutterOverlayWindow.isPermissionGranted();

  /// Opens Android's "Display over other apps" page.
  static Future<bool> requestPermission() async =>
      isSupported && (await FlutterOverlayWindow.requestPermission() ?? false);

  /// Collapsed and picker-open heights, in dp.
  static const collapsedDp = 340;
  static const expandedDp = 560;

  static Future<void> show(SplitPrompt prompt, AppStore store, {required bool expanded}) async {
    await store.writeSplitPrompt(prompt);
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.shareData('prompt'); // already up: reload
      return;
    }
    // The first show takes pixels; later resizes take dp.
    final ratio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    await FlutterOverlayWindow.showOverlay(
      height: ((expanded ? expandedDp : collapsedDp) * ratio).round(),
      width: WindowSize.matchParent,
      alignment: OverlayAlignment.bottomCenter,
      flag: OverlayFlag.focusPointer,
      enableDrag: true,
      overlayTitle: 'Auto Spend',
      overlayContent: 'Split this payment?',
    );
  }

  /// Messages from the floating card to the app (e.g. "a split happened").
  static Stream<dynamic> get messages => FlutterOverlayWindow.overlayListener;
}

/// Overlay side: its own Flutter engine, launched from `overlayMain`.
class SplitOverlayApp extends StatelessWidget {
  const SplitOverlayApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const _Floating(),
      );
}

class _Floating extends StatefulWidget {
  const _Floating();

  @override
  State<_Floating> createState() => _FloatingState();
}

class _FloatingState extends State<_Floating> {
  final _store = AppStore();
  StreamSubscription<dynamic>? _messages;
  SplitPrompt? _prompt;
  SplitTarget? _target;
  ({List<SwGroup> groups, List<SwUser> friends})? _sw;
  String? _key;

  @override
  void initState() {
    super.initState();
    _load();
    // Re-shown for a newer payment while already open.
    _messages = FlutterOverlayWindow.overlayListener.listen((m) {
      if (m == 'prompt') _load();
    });
  }

  Future<void> _load() async {
    final prompt = await _store.readSplitPrompt();
    final target = await _store.readSplitTarget();
    final cache = await _store.readSplitwiseCache();
    final key = await _store.readSplitwiseKey();
    if (!mounted) return;
    setState(() {
      _prompt = prompt;
      _target = target;
      _sw = (groups: cache.groups, friends: cache.friends);
      _key = key;
    });
  }

  Future<void> _split(SplitTarget target, bool makeDefault) async {
    final cache = await _store.readSplitwiseCache();
    final api = _key == null ? DemoSplitwiseApi() : HttpSplitwiseApi(_key!);
    final record = await splitOnSplitwise(
      api: api,
      target: target,
      myUserId: cache.user?.user.id ?? 1,
      prompt: _prompt!,
      currency: cache.user?.defaultCurrency ?? appCurrency,
    );
    await _store.addSplitRecord(record);
    if (makeDefault) await _store.writeSplitTarget(target);
    await FlutterOverlayWindow.shareData('split');
  }

  void _resize(bool expanded) => FlutterOverlayWindow.resizeOverlay(
        WindowSize.matchParent,
        expanded ? SplitOverlay.expandedDp : SplitOverlay.collapsedDp,
        true,
      );

  @override
  void dispose() {
    _messages?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prompt = _prompt;
    final sw = _sw;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: prompt == null || sw == null
              ? const SizedBox.shrink()
              : SingleChildScrollView(
                  child: SplitCard(
                    key: ValueKey(prompt.txnId),
                    prompt: prompt,
                    groups: sw.groups,
                    friends: sw.friends,
                    defaultTarget: _target,
                    demo: _key == null,
                    onSplit: _split,
                    onDismiss: FlutterOverlayWindow.closeOverlay,
                    onExpandedChanged: _resize,
                  ),
                ),
        ),
      ),
    );
  }
}
