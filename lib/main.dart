import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'overlay/split_bubble.dart';
import 'screens/home_screen.dart';
import 'storage/app_store.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(AppStore())..init();
  runApp(AutoSplitApp(controller: controller));
}

/// Entry point for the floating bubble, which Android runs in its own engine.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SplitBubbleApp());
}

class AutoSplitApp extends StatelessWidget {
  const AutoSplitApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AppScope(
        controller: controller,
        child: MaterialApp(
          title: 'Auto Split',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          home: const HomeScreen(),
        ),
      );
}
