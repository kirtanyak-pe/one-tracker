import 'package:auto_split/app_controller.dart';
import 'package:auto_split/screens/shell.dart';
import 'package:auto_split/storage/app_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/onyx.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('switching tabs fully hides the previous tab', (tester) async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    // Not Android: no SMS/notification plugins, sample data like the web preview.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(375 * 3, 812 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final controller = AppController(AppStore());
    await tester.runAsync(controller.init);
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: const OApp(title: 'test', mode: OThemeMode.light, home: AppShell()),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byIcon(LucideIcons.chartNoAxesColumn));
    await tester.pump(); // starts the fade
    await tester.pump(const Duration(seconds: 1));

    // Insights is showing; Home has faded out and is now fully offstage (no
    // layout or paint at all) rather than stuck half-visible.
    Offstage tab(int i) => tester.widget<Offstage>(find.byKey(ValueKey('tab-$i'), skipOffstage: false));
    expect(tab(1).offstage, isFalse);
    expect(tab(0).offstage, isTrue, reason: 'Home should be fully hidden after the fade');
    final insightsFade = tester.widget<FadeTransition>(
      find.descendant(of: find.byKey(const ValueKey('tab-1')), matching: find.byType(FadeTransition)).first,
    );
    expect(insightsFade.opacity.value, 1);
    // Tabs never opened aren't built (Activity shows only its nav label).
    expect(find.text('Search payee, #tag or amount', skipOffstage: false), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
