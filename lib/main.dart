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
  runApp(OneTrackerApp(controller: controller));
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

class OneTrackerApp extends StatelessWidget {
  const OneTrackerApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AppScope(
        controller: controller,
        // Rebuilds when the theme choice or wallpaper colour changes.
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => MaterialApp(
            title: 'One Tracker',
            debugShowCheckedModeBanner: false,
            themeMode: controller.appearance.mode,
            theme: buildTheme(Brightness.light, seed: controller.themeSeed),
            darkTheme: buildTheme(Brightness.dark, seed: controller.themeSeed),
            // Lite mode: every Motion animation becomes instant.
            builder: (context, child) => controller.lite
                ? MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!)
                : child!,
            home: const AppShell(),
          ),
        ),
      );
}
