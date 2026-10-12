import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'screens/shell.dart';
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
