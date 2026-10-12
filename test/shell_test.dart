import 'package:auto_split/app_controller.dart';
import 'package:auto_split/screens/shell.dart';
import 'package:auto_split/storage/app_store.dart';
import 'package:auto_split/ui/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('switching tabs fully hides the previous tab', (tester) async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    FlutterSecureStorage.setMockInitialValues({});
    // Not Android: no SMS/notification plugins, sample data like the web preview.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(375 * 3, 812 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final controller = AppController(AppStore());
    await tester.runAsync(controller.init);
    await tester.pumpWidget(AppScope(
      controller: controller,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: const AppShell()),
    ));
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pump(); // starts the fade
    await tester.pump(const Duration(seconds: 1));

    // AnimatedOpacity renders through a FadeTransition; read its live value.
    double shown(int tab) => tester
        .widget<FadeTransition>(find
            .descendant(of: find.byType(AnimatedOpacity).at(tab), matching: find.byType(FadeTransition))
            .first)
        .opacity
        .value;
    expect(shown(0), 0, reason: 'Home should have faded out completely');
    expect(shown(1), 1);
    debugDefaultTargetPlatformOverride = null;
  });
}
