import 'package:flutter/material.dart';

ThemeData buildTheme(Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1B9E77),
        brightness: brightness,
      ),
      useMaterial3: true,
    );
