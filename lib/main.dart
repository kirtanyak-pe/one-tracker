import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'screens/shell.dart';
import 'sources/live_sms.dart';
import 'split/split_overlay.dart';
import 'storage/app_store.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(AppStore())..init();
  runApp(AutoSpendApp(controller: controller));
}

/// Entry point for the floating split card (its own engine, see SplitOverlay).
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SplitOverlayApp());
}

/// A bank SMS arrived while the app was closed: SmsReceiver.kt starts a
/// short-lived engine here. Args: sender, body, timestamp ms, pixel ratio.
@pragma('vm:entry-point')
Future<void> smsMain(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await handleBackgroundSms(
      sender: args[0],
      body: args[1],
      at: DateTime.fromMillisecondsSinceEpoch(int.parse(args[2])),
      pixelRatio: double.tryParse(args[3]) ?? 2.625,
    );
  } catch (e, s) {
    debugPrint('Background SMS failed: $e\n$s');
  } finally {
    await const MethodChannel('auto_spend/sms').invokeMethod('done');
  }
}

class AutoSpendApp extends StatelessWidget {
  const AutoSpendApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AppScope(
        controller: controller,
        child: MaterialApp(
          title: 'Auto Spend',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          home: const AppShell(),
        ),
      );
}
