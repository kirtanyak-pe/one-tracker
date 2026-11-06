import 'package:flutter/widgets.dart';

import 'finish.dart';
import 'tokens.dart';
import 'tokens.g.dart';

const _pkg = 'onyx';

/// The type ramp. Inter for text, Inter Display for big numbers; tight
/// tracking as sizes grow. Money uses [TextStyleX.tabular].
@immutable
class OType {
  const OType({
    required this.hero,
    required this.display,
    required this.title1,
    required this.title2,
    required this.title3,
    required this.body,
    required this.bodyStrong,
    required this.small,
    required this.smallStrong,
    required this.caption,
    required this.label,
    required this.overline,
  });

  factory OType.of(OColors c) {
    // Sizes, weights, tracking and line heights come from tokens/onyx.tokens.json.
    TextStyle s(OTypeToken t) => TextStyle(
      fontFamily: t.display ? OTokenType.displayFamily : OTokenType.family,
      package: _pkg,
      fontSize: t.size,
      fontWeight: t.weight,
      letterSpacing: t.tracking,
      height: t.height,
      color: t.ink == OTypeInk.inkSoft ? c.inkSoft : c.ink,
      // Inter's open digits, straight 6/9 and disambiguated l/I.
      fontFeatures: OTokenType.features,
    );
    return OType(
      hero: s(OTokenType.hero),
      display: s(OTokenType.display),
      title1: s(OTokenType.title1),
      title2: s(OTokenType.title2),
      title3: s(OTokenType.title3),
      body: s(OTokenType.body),
      bodyStrong: s(OTokenType.bodyStrong),
      small: s(OTokenType.small),
      smallStrong: s(OTokenType.smallStrong),
      caption: s(OTokenType.caption),
      label: s(OTokenType.label),
      overline: s(OTokenType.overline),
    );
  }

  /// 56 · Display numbers (a balance, a total).
  final TextStyle hero;

  /// 36 · Large numbers on detail screens.
  final TextStyle display;
  final TextStyle title1;
  final TextStyle title2;
  final TextStyle title3;
  final TextStyle body;
  final TextStyle bodyStrong;

  /// Secondary text, in inkSoft.
  final TextStyle small;
  final TextStyle smallStrong;

  /// Metadata, in inkSoft.
  final TextStyle caption;

  /// Buttons and controls.
  final TextStyle label;

  /// UPPERCASE section labels, in inkSoft.
  final TextStyle overline;
}

extension TextStyleX on TextStyle {
  /// Same-width digits, so amounts line up and don't jitter as they count.
  TextStyle get tabular => copyWith(
    fontFeatures: [...?fontFeatures, const FontFeature.tabularFigures()],
  );
  TextStyle tint(Color c) => copyWith(color: c);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get semibold => copyWith(fontWeight: FontWeight.w600);
}

enum OThemeMode { system, light, dark }

@immutable
class OThemeData {
  OThemeData({
    required this.brightness,
    required this.colors,
    this.finish = OFinish.raised,
  }) : type = OType.of(colors);

  factory OThemeData.light() =>
      OThemeData(brightness: Brightness.light, colors: OColors.light);
  factory OThemeData.dark() =>
      OThemeData(brightness: Brightness.dark, colors: OColors.dark);

  final Brightness brightness;
  final OColors colors;
  final OType type;

  /// How pressable things look; see [OFinish].
  final OFinish finish;

  OThemeData withFinish(OFinish f) => f == finish
      ? this
      : OThemeData(brightness: brightness, colors: colors, finish: f);

  bool get isDark => brightness == Brightness.dark;
}

class OTheme extends InheritedWidget {
  const OTheme({super.key, required this.data, required super.child});

  final OThemeData data;

  static OThemeData of(BuildContext context) {
    final t = context.dependOnInheritedWidgetOfExactType<OTheme>();
    assert(t != null, 'No OTheme above this widget: wrap the app in OApp.');
    return t!.data;
  }

  @override
  bool updateShouldNotify(OTheme old) =>
      old.data.brightness != data.brightness ||
      old.data.colors != data.colors ||
      old.data.finish != data.finish;
}

extension OContext on BuildContext {
  OThemeData get onyx => OTheme.of(this);
  OColors get colors => OTheme.of(this).colors;
  OType get type => OTheme.of(this).type;
}
