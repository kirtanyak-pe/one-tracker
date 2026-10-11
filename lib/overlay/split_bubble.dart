import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../detection/detected_payment.dart';
import '../splitwise/models.dart';
import '../splitwise/splitwise_api.dart';
import '../storage/app_store.dart';
import '../history/split_record.dart';
import '../ui/theme.dart';
import '../ui/tokens.dart';
import 'quick_split_card.dart';

/// Main-app side: permission + opening the floating bubble.
class SplitBubble {
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> hasPermission() async =>
      isSupported && await FlutterOverlayWindow.isPermissionGranted();

  /// Opens Android's "Display over other apps" settings page.
  static Future<bool> requestPermission() async =>
      isSupported && (await FlutterOverlayWindow.requestPermission() ?? false);

  static Future<void> show(DetectedPayment payment, AppStore store) async {
    await store.writeBubblePayment(payment);
    if (await FlutterOverlayWindow.isActive()) {
      // Bubble already up: tell it about the newer payment.
      await FlutterOverlayWindow.shareData(jsonEncode(payment.toJson()));
      return;
    }
    // Overlay sizes are physical pixels, not dp.
    final ratio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    await FlutterOverlayWindow.showOverlay(
      height: (380 * ratio).round(),
      width: WindowSize.matchParent,
      alignment: OverlayAlignment.bottomCenter,
      flag: OverlayFlag.defaultFlag,
      enableDrag: true,
      overlayTitle: 'Auto Split',
      overlayContent: 'Payment detected',
    );
  }
}

/// Bubble side: runs in its own isolate (see `overlayMain` in main.dart),
/// reads everything it needs from [AppStore] and posts straight to Splitwise.
class SplitBubbleApp extends StatelessWidget {
  const SplitBubbleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const _Bubble(),
      );
}

class _Bubble extends StatefulWidget {
  const _Bubble();

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  final _store = AppStore();
  DetectedPayment? _payment;
  List<SwGroup> _groups = [];
  String _currency = 'INR';
  StreamSubscription<dynamic>? _messages;

  @override
  void initState() {
    super.initState();
    _load();
    _messages = FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is String) {
        setState(() => _payment =
            DetectedPayment.fromJson(jsonDecode(data) as Map<String, dynamic>));
      }
    });
  }

  Future<void> _load() async {
    final payment = await _store.readBubblePayment();
    final groups = await _store.readCachedGroups();
    final currency = await _store.readCurrency();
    if (!mounted) return;
    setState(() {
      _payment = payment;
      _groups = groups;
      _currency = currency;
    });
  }

  Future<void> _split(SwGroup group) async {
    final payment = _payment!;
    final key = await _store.readApiKey();
    final api = key == null ? DemoSplitwiseApi() : HttpSplitwiseApi(key);
    await api.createGroupExpense(
      groupId: group.id,
      costMinor: payment.amountMinor,
      description: payment.merchant ?? 'Payment',
      currency: _currency,
    );
    await _store.removeFromInbox(payment.id);
    await _store.addHistory(SplitRecord(
      amountMinor: payment.amountMinor,
      description: payment.merchant ?? 'Payment',
      withWhom: group.name,
      at: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _messages?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payment = _payment;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: payment == null
              ? const SizedBox.shrink()
              : QuickSplitCard(
                  key: ValueKey(payment.id),
                  payment: payment,
                  groups: _groups,
                  currency: _currency,
                  onSplit: _split,
                  // Leaves it in the app's "To split" list.
                  onLater: FlutterOverlayWindow.closeOverlay,
                ),
        ),
      ),
    );
  }
}
