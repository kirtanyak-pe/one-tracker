import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'finish.dart';
import 'theme.dart';
import 'tokens.dart';

/// The app root: a [WidgetsApp] with Onyx's theme, type, scrolling and page
/// transitions — no Material underneath.
class OApp extends StatelessWidget {
  const OApp({
    super.key,
    required this.title,
    required this.home,
    this.mode = OThemeMode.system,
    this.finish,
    this.light,
    this.dark,
    this.builder,
    this.navigatorKey,
  });

  final String title;
  final Widget home;
  final OThemeMode mode;

  /// How pressable things look; default [OFinish.raised].
  final OFinish? finish;

  /// Overrides for an app that tunes the palette (say, its own accent).
  final OThemeData? light;
  final OThemeData? dark;
  final TransitionBuilder? builder;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) => WidgetsApp(
    title: title,
    color: (light ?? OThemeData.light()).colors.ink,
    navigatorKey: navigatorKey,
    debugShowCheckedModeBanner: false,
    home: home,
    pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
        OPageRoute<T>(settings: settings, builder: builder),
    builder: (context, child) {
      final b = switch (mode) {
        OThemeMode.light => Brightness.light,
        OThemeMode.dark => Brightness.dark,
        OThemeMode.system => MediaQuery.platformBrightnessOf(context),
      };
      var data = b == Brightness.dark ? (dark ?? OThemeData.dark()) : (light ?? OThemeData.light());
      if (finish case final f?) data = data.withFinish(f);
      final c = data.colors;
      final inner = builder?.call(context, child) ?? child!;
      return OTheme(
        data: data,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: (data.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
            statusBarColor: const Color(0x00000000),
            systemNavigationBarColor: const Color(0x00000000),
            systemNavigationBarContrastEnforced: false,
          ),
          child: DefaultTextStyle(
            style: data.type.body,
            child: IconTheme(
              data: IconThemeData(color: c.ink, size: 22),
              child: DefaultSelectionStyle(
                cursorColor: c.accent,
                selectionColor: c.accent.withValues(alpha: 0.28),
                child: ScrollConfiguration(
                  behavior: const OScrollBehavior(),
                  child: OBackground(child: inner),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Bouncing, glow-free scrolling on every platform.
class OScrollBehavior extends ScrollBehavior {
  const OScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}

/// Push a screen with Onyx's transition.
Future<T?> pushScreen<T>(BuildContext context, Widget screen) =>
    Navigator.of(context).push<T>(OPageRoute<T>(builder: (_) => screen));

/// The new page slides in from the right over a page that drifts left and
/// dims a touch.
class OPageRoute<T> extends PageRoute<T> {
  OPageRoute({required this.builder, super.settings});

  final WidgetBuilder builder;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => OMotion.slow;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      // Opaque: a page never shows the one beneath through gaps.
      OBackground(child: builder(context));

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final enter = CurvedAnimation(parent: animation, curve: OMotion.emphasized, reverseCurve: OMotion.standard.flipped);
    final under = CurvedAnimation(parent: secondaryAnimation, curve: OMotion.standard);
    return SlideTransition(
      position: Tween(begin: Offset.zero, end: const Offset(-0.22, 0)).animate(under),
      child: SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(enter),
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: animation.isCompleted ? null : OShadow.floating(context.onyx.brightness),
          ),
          child: child,
        ),
      ),
    );
  }
}
