import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'screens/shell.dart';
import 'storage/app_store.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(AppStore())..init();
  runApp(AutoSpendApp(controller: controller));
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
