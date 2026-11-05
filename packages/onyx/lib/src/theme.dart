import 'package:flutter/widgets.dart';

import 'finish.dart';
import 'tokens.dart';

const _font = 'Inter';
const _display = 'InterDisplay';
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
    TextStyle s(
      double size,
      FontWeight w, {
      double? tracking,
      double height = 1.35,
      Color? color,
      bool display = false,
    }) => TextStyle(
      fontFamily: display ? _display : _font,
      package: _pkg,
      fontSize: size,
      fontWeight: w,
      letterSpacing: tracking,
      height: height,
      color: color ?? c.ink,
      // Inter's open digits, straight 6/9 and disambiguated l/I.
      fontFeatures: const [FontFeature('cv05'), FontFeature('cv08')],
    );
    return OType(
      hero: s(56, FontWeight.w600, tracking: -2.2, height: 1.05, display: true),
      display: s(36, FontWeight.w600, tracking: -1.2, height: 1.1, display: true),
      title1: s(28, FontWeight.w600, tracking: -0.7, height: 1.15),
      title2: s(22, FontWeight.w600, tracking: -0.45, height: 1.2),
      title3: s(17, FontWeight.w600, tracking: -0.2, height: 1.3),
      body: s(15, FontWeight.w400, tracking: -0.1),
      bodyStrong: s(15, FontWeight.w500, tracking: -0.1),
      small: s(13, FontWeight.w400, color: c.inkSoft),
      smallStrong: s(13, FontWeight.w500),
      caption: s(12, FontWeight.w500, tracking: 0.1, color: c.inkSoft),
      label: s(15, FontWeight.w600, tracking: -0.1, height: 1.2),
      overline: s(11, FontWeight.w600, tracking: 0.8, color: c.inkSoft),
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
  TextStyle get tabular => copyWith(fontFeatures: [...?fontFeatures, const FontFeature.tabularFigures()]);
  TextStyle tint(Color c) => copyWith(color: c);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get semibold => copyWith(fontWeight: FontWeight.w600);
}

enum OThemeMode { system, light, dark }

@immutable
class OThemeData {
  OThemeData({required this.brightness, required this.colors, this.finish = OFinish.raised}) : type = OType.of(colors);

  factory OThemeData.light() => OThemeData(brightness: Brightness.light, colors: OColors.light);
  factory OThemeData.dark() => OThemeData(brightness: Brightness.dark, colors: OColors.dark);

  final Brightness brightness;
  final OColors colors;
  final OType type;

  /// How pressable things look; see [OFinish].
  final OFinish finish;

  OThemeData withFinish(OFinish f) =>
      f == finish ? this : OThemeData(brightness: brightness, colors: colors, finish: f);

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
      old.data.brightness != data.brightness || old.data.colors != data.colors || old.data.finish != data.finish;
}

extension OContext on BuildContext {
  OThemeData get onyx => OTheme.of(this);
  OColors get colors => OTheme.of(this).colors;
  OType get type => OTheme.of(this).type;
}
