import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../money.dart';
import '../splitwise/models.dart';
import '../splitwise/splitwise_api.dart';
import '../storage/app_store.dart';
import '../ui/motion.dart';
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

  /// First-show height in dp; the card then sizes the window to fit.
  static const initialDp = 380;

  /// Gap below the status bar, dp.
  static const topDp = 44;

  /// [pixelRatio] is needed when there's no screen to ask (background start).
  static Future<void> show(SplitPrompt prompt, AppStore store, {bool expanded = false, double? pixelRatio}) async {
    await store.writeSplitPrompt(prompt);
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.shareData('prompt'); // already up: reload
      return;
    }
    // The first show takes pixels; later resizes take dp.
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final ratio = pixelRatio ?? (views.isEmpty ? 2.625 : views.first.devicePixelRatio);
    await FlutterOverlayWindow.showOverlay(
      height: (initialDp * ratio).round(),
      width: WindowSize.matchParent,
      // Heads-up style: top of the screen, under the status bar.
      alignment: OverlayAlignment.topCenter,
      startPosition: const OverlayPosition(0, topDp * 1.0),
      flag: OverlayFlag.focusPointer,
      // We handle swipes ourselves; the plugin's drag can fling the window
      // off-screen.
      enableDrag: false,
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
  final _card = GlobalKey<SplitCardState>();
  StreamSubscription<dynamic>? _messages;
  double _windowDp = SplitOverlay.initialDp.toDouble();
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
    debugPrint('SplitOverlay load: prompt=${prompt?.txnId} groups=${cache.groups.length} target=${target?.label}');
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

  /// Sizes the window to the card (font size, picker, done state all change
  /// it), capped so it never becomes a full-screen page.
  void _fit(Size card) {
    // The overlay engine may not know the display (reports 0); fall back to
    // a typical phone height rather than clamping to nothing.
    final display = View.of(context).display;
    final reported = display.devicePixelRatio > 0 ? display.size.height / display.devicePixelRatio : 0.0;
    final screenDp = reported > 300 ? reported : 800.0;
    final wanted = math.min(card.height + Space.md * 2, screenDp * 0.8);
    debugPrint('SplitOverlay fit: card=${card.height.toStringAsFixed(0)} screen=$reported -> $wanted');
    if (card.height < 100) return; // not laid out properly yet
    if ((wanted - _windowDp).abs() < 2) return;
    _windowDp = wanted;
    FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, wanted.ceil(), false);
  }

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
      body: prompt == null || sw == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.all(Space.md),
              child: _SwipeAway(
                onDismiss: () {
                  debugPrint('SplitOverlay: swiped away');
                  FlutterOverlayWindow.closeOverlay();
                },
                onPullDown: () => _card.currentState?.openPicker(),
                // Scrolls when capped (long picker on a small screen).
                child: SingleChildScrollView(
                  child: _MeasureSize(
                    onChange: _fit,
                    child: SplitCard(
                      key: _card,
                      prompt: prompt,
                      groups: sw.groups,
                      friends: sw.friends,
                      defaultTarget: _target,
                      demo: _key == null,
                      onSplit: _split,
                      onDismiss: () {
                        debugPrint('SplitOverlay: closed from card');
                        FlutterOverlayWindow.closeOverlay();
                      },
                      showHandle: true,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Swipe up or sideways to dismiss; pull down for more. Springs back
/// otherwise. Heads-up-notification feel.
class _SwipeAway extends StatefulWidget {
  const _SwipeAway({required this.child, required this.onDismiss, required this.onPullDown});

  final Widget child;
  final VoidCallback onDismiss;
  final VoidCallback onPullDown;

  @override
  State<_SwipeAway> createState() => _SwipeAwayState();
}

class _SwipeAwayState extends State<_SwipeAway> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: Motion.medium);
  Offset _drag = Offset.zero;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  bool _leaving = false;

  Offset get _offset => _anim.isAnimating ? Offset.lerp(_from, _to, Curves.easeOut.transform(_anim.value))! : _drag;

  void _animateTo(Offset target, {VoidCallback? then}) {
    _from = _drag;
    _to = target;
    _anim.forward(from: 0).whenComplete(() {
      _drag = target;
      then?.call();
    });
  }

  void _end(DragEndDetails d, {required bool horizontal}) {
    final v = d.velocity.pixelsPerSecond;
    final width = MediaQuery.sizeOf(context).width;
    if (horizontal && (_drag.dx.abs() > width * 0.3 || v.dx.abs() > 700)) {
      _leaving = true;
      _animateTo(Offset(_drag.dx.sign * width, 0), then: widget.onDismiss);
    } else if (!horizontal && (_drag.dy < -48 || v.dy < -600)) {
      _leaving = true;
      _animateTo(const Offset(0, -600), then: widget.onDismiss);
    } else {
      if (!horizontal && (_drag.dy > 48 || v.dy > 600)) widget.onPullDown();
      _animateTo(Offset.zero);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onVerticalDragUpdate: _leaving
            ? null
            : (d) => setState(() {
                  // Up moves freely; down resists (it's a pull, not a move).
                  final dy = d.delta.dy;
                  _drag = Offset(0, _drag.dy + (dy > 0 || _drag.dy > 0 ? dy * 0.35 : dy));
                }),
        onVerticalDragEnd: _leaving ? null : (d) => _end(d, horizontal: false),
        onHorizontalDragUpdate: _leaving ? null : (d) => setState(() => _drag = Offset(_drag.dx + d.delta.dx, 0)),
        onHorizontalDragEnd: _leaving ? null : (d) => _end(d, horizontal: true),
        child: AnimatedBuilder(
          animation: _anim,
          child: widget.child,
          builder: (context, child) {
            final o = _offset;
            final width = MediaQuery.sizeOf(context).width;
            final fade = (1 - (o.dx.abs() / width) - (o.dy < 0 ? -o.dy / 300 : 0)).clamp(0.0, 1.0);
            return Opacity(opacity: fade, child: Transform.translate(offset: o, child: child));
          },
        ),
      );
}

/// Reports its child's size during layout (no post-frame guesswork).
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasureSize renderObject) => renderObject.onChange = onChange;
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    final s = child?.size;
    if (s == null || s == _last) return;
    _last = s;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(s));
  }
}
