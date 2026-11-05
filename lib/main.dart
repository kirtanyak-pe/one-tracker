import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:onyx/onyx.dart';

import 'app_controller.dart';
import 'screens/shell.dart';
import 'sources/live_sms.dart';
import 'storage/app_store.dart';
import 'ui/app_lock.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(AppStore())..init();
  runApp(OneTrackerApp(controller: controller));
}

/// A bank SMS arrived while the app was closed: SmsReceiver.kt starts a
/// short-lived engine here. Args: sender, body, timestamp ms, (density).
@pragma('vm:entry-point')
Future<void> smsMain(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await handleBackgroundSms(
      sender: args[0],
      body: args[1],
      at: DateTime.fromMillisecondsSinceEpoch(int.parse(args[2])),
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
    // Rebuilds when the theme choice or lite mode changes.
    child: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => OApp(
        title: 'One Tracker',
        mode: controller.appearance.mode,
        // Lite mode: every Motion animation becomes instant.
        builder: (context, child) => AppLock(
          controller: controller,
          child: controller.lite
              ? MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!)
              : child!,
        ),
        home: const AppShell(),
      ),
    ),
  );
}
