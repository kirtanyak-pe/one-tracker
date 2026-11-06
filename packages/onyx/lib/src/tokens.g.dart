// GENERATED — edit onyx.tokens.json, run node packages/onyx/tokens/generate.mjs
// ignore_for_file: type=lint
import 'package:flutter/widgets.dart';

/// light colour roles (OColors.light).
abstract final class OTokenLight {
  static const canvas = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const raised = Color(0xFFECEFF3);
  static const line = Color(0xFFE3E7ED);
  static const lineStrong = Color(0xFFC9CFD8);
  static const ink = Color(0xFF0A0D14);
  static const inkSoft = Color(0xFF5A6272);
  static const inkFaint = Color(0xFF99A1AE);
  static const onInk = Color(0xFFFFFFFF);
  static const accent = Color(0xFF3E63DD);
  static const onAccent = Color(0xFFFFFFFF);
  static const positive = Color(0xFF0B7A4D);
  static const negative = Color(0xFFC4262F);
  static const warning = Color(0xFF8F5700);
  static const scrim = Color(0x660A0D14);
}

/// dark colour roles (OColors.dark).
abstract final class OTokenDark {
  static const canvas = Color(0xFF07090C);
  static const surface = Color(0xFF12151A);
  static const raised = Color(0xFF1A1E24);
  static const line = Color(0xFF222730);
  static const lineStrong = Color(0xFF333A45);
  static const ink = Color(0xFFF2F5F9);
  static const inkSoft = Color(0xFF9EA6B4);
  static const inkFaint = Color(0xFF646C7A);
  static const onInk = Color(0xFF0A0D14);
  static const accent = Color(0xFF7C9CFF);
  static const onAccent = Color(0xFF0A0D14);
  static const positive = Color(0xFF34D399);
  static const negative = Color(0xFFFF6370);
  static const warning = Color(0xFFF5B544);
  static const scrim = Color(0x99000000);
}

abstract final class OTokenSpace {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 48.0;
  static const gutter = 20.0;
}

abstract final class OTokenRadius {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
  static const pill = 999.0;
}

abstract final class OTokenMotion {
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 380);
  static const standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const emphasized = Cubic(0.05, 0.7, 0.1, 1.0);
  static const exit = Cubic(0.3, 0.0, 1.0, 1.0);
}

abstract final class OTokenShadow {
  static const floatingLight = <BoxShadow>[BoxShadow(color: Color(0x14000000), blurRadius: 32.0, offset: Offset(0.0, 12.0)), BoxShadow(color: Color(0x0A000000), blurRadius: 3.0, offset: Offset(0.0, 1.0))];
  static const floatingDark = <BoxShadow>[BoxShadow(color: Color(0x66000000), blurRadius: 32.0, offset: Offset(0.0, 12.0))];
  static const subtleLight = <BoxShadow>[BoxShadow(color: Color(0x0D000000), blurRadius: 8.0, offset: Offset(0.0, 2.0))];
  static const subtleDark = <BoxShadow>[];
  static const tabBarBlurSigma = 18.0;
  static const scrimBlurSigma = 6.0;
}

/// Which colour a type style takes.
enum OTypeInk { ink, inkSoft }

/// One style of the type ramp. A null [tracking] leaves letter spacing alone.
class OTypeToken {
  const OTypeToken(this.size, this.weight, this.tracking, this.height, this.display, this.ink);
  final double size;
  final FontWeight weight;
  final double? tracking;
  final double height;
  final bool display;
  final OTypeInk ink;
}

abstract final class OTokenType {
  static const family = 'Inter';
  static const displayFamily = 'InterDisplay';
  static const features = [FontFeature('cv05'), FontFeature('cv08')];
  static const hero = OTypeToken(56.0, FontWeight.w600, -2.2, 1.05, true, OTypeInk.ink);
  static const display = OTypeToken(36.0, FontWeight.w600, -1.2, 1.1, true, OTypeInk.ink);
  static const title1 = OTypeToken(28.0, FontWeight.w600, -0.7, 1.15, false, OTypeInk.ink);
  static const title2 = OTypeToken(22.0, FontWeight.w600, -0.45, 1.2, false, OTypeInk.ink);
  static const title3 = OTypeToken(17.0, FontWeight.w600, -0.2, 1.3, false, OTypeInk.ink);
  static const body = OTypeToken(15.0, FontWeight.w400, -0.1, 1.35, false, OTypeInk.ink);
  static const bodyStrong = OTypeToken(15.0, FontWeight.w500, -0.1, 1.35, false, OTypeInk.ink);
  static const small = OTypeToken(13.0, FontWeight.w400, null, 1.35, false, OTypeInk.inkSoft);
  static const smallStrong = OTypeToken(13.0, FontWeight.w500, null, 1.35, false, OTypeInk.ink);
  static const caption = OTypeToken(12.0, FontWeight.w500, 0.1, 1.35, false, OTypeInk.inkSoft);
  static const label = OTypeToken(15.0, FontWeight.w600, -0.1, 1.2, false, OTypeInk.ink);
  static const overline = OTypeToken(11.0, FontWeight.w600, 0.8, 1.35, false, OTypeInk.inkSoft);
}

/// Tint bases: [glow] is the fill's own colour when it is saturated, else the accent.
enum OTintBase { black, white, accent, glow }

class OTint {
  const OTint(this.base, this.alpha);
  final OTintBase base;
  final double alpha;
}

/// [color] x [dx] y [dy] with a blur radius (CSS blur, so the sigma is half).
class OShadowToken {
  const OShadowToken(this.tint, this.blur, this.dy, [this.dx = 0]);
  final OTint tint;
  final double blur;
  final double dy;
  final double dx;
}

/// What a finish adds over a fill, at one depth and mode. See onyx.tokens.json.
class ORecipeToken {
  const ORecipeToken({
    this.fillCanvas = false,
    this.fillAlpha = 1,
    this.sheen = const [],
    this.sheenOnWhite,
    this.sheenStops,
    this.highlight,
    this.shade,
    this.rim,
    this.shadows = const [],
    this.insets = const [],
    this.pressedShade,
  });
  final bool fillCanvas;
  final double fillAlpha;
  final List<OTint> sheen;
  final List<OTint>? sheenOnWhite;
  final List<double>? sheenStops;
  final OTint? highlight;
  final OTint? shade;
  final OTint? rim;
  final List<OShadowToken> shadows;
  final List<OShadowToken> insets;
  final OTint? pressedShade;
}

/// A radial wash behind the screen. [x] and [y] are fractions of the width and height ([yOfWidth]: y is a fraction of the width); a null [color] is the accent.
class OWashToken {
  const OWashToken(this.x, this.y, this.yOfWidth, this.radius, this.color, this.alpha);
  final double x;
  final double y;
  final bool yOfWidth;
  final double radius;
  final Color? color;
  final double alpha;
}

abstract final class OTokenFinish {
  static const hairlines = {'flat', 'raised'};
  static const pressedShade = OTint(OTintBase.black, 0.251);
  /// Keyed '<finish>.<light|dark>.<depth>'.
  static const recipes = <String, ORecipeToken>{
    'flat.light.strong': ORecipeToken(),
    'flat.light.soft': ORecipeToken(),
    'flat.light.surface': ORecipeToken(),
    'flat.light.well': ORecipeToken(),
    'flat.dark.strong': ORecipeToken(),
    'flat.dark.soft': ORecipeToken(),
    'flat.dark.surface': ORecipeToken(),
    'flat.dark.well': ORecipeToken(),
    'raised.light.strong': ORecipeToken(sheen: [OTint(OTintBase.white, 0.14), OTint(OTintBase.black, 0.1)], highlight: OTint(OTintBase.white, 0.22), shade: OTint(OTintBase.black, 0.35), shadows: [OShadowToken(OTint(OTintBase.black, 0.16), 3.0, 1.0), OShadowToken(OTint(OTintBase.black, 0.1), 10.0, 4.0)]),
    'raised.light.soft': ORecipeToken(sheen: [OTint(OTintBase.white, 0.1), OTint(OTintBase.white, 0.0)], sheenOnWhite: [OTint(OTintBase.black, 0.0), OTint(OTintBase.black, 0.04)], highlight: OTint(OTintBase.white, 1.0), shade: OTint(OTintBase.black, 0.1), shadows: [OShadowToken(OTint(OTintBase.black, 0.08), 3.0, 1.0), OShadowToken(OTint(OTintBase.black, 0.05), 8.0, 3.0)]),
    'raised.light.surface': ORecipeToken(shade: OTint(OTintBase.black, 0.04), shadows: [OShadowToken(OTint(OTintBase.black, 0.04), 2.0, 1.0), OShadowToken(OTint(OTintBase.black, 0.03), 12.0, 4.0)]),
    'raised.light.well': ORecipeToken(shade: OTint(OTintBase.white, 0.7), insets: [OShadowToken(OTint(OTintBase.black, 0.06), 3.0, 1.0)]),
    'raised.dark.strong': ORecipeToken(sheen: [OTint(OTintBase.white, 0.2), OTint(OTintBase.black, 0.15)], highlight: OTint(OTintBase.white, 0.25), shade: OTint(OTintBase.black, 0.3), shadows: [OShadowToken(OTint(OTintBase.black, 0.2), 4.0, 1.0), OShadowToken(OTint(OTintBase.black, 0.3), 6.0, 2.0)]),
    'raised.dark.soft': ORecipeToken(sheen: [OTint(OTintBase.white, 0.05), OTint(OTintBase.white, 0.0)], highlight: OTint(OTintBase.white, 0.05), shade: OTint(OTintBase.black, 0.2), shadows: [OShadowToken(OTint(OTintBase.black, 0.2), 4.0, 1.0)]),
    'raised.dark.surface': ORecipeToken(highlight: OTint(OTintBase.white, 0.04), shadows: [OShadowToken(OTint(OTintBase.black, 0.3), 8.0, 2.0)]),
    'raised.dark.well': ORecipeToken(shade: OTint(OTintBase.white, 0.04), insets: [OShadowToken(OTint(OTintBase.black, 0.35), 3.0, 1.0)]),
    'pillow.light.strong': ORecipeToken(sheen: [OTint(OTintBase.white, 0.16), OTint(OTintBase.black, 0.1)], shadows: [OShadowToken(OTint(OTintBase.black, 0.16), 14.0, 5.0, 5.0), OShadowToken(OTint(OTintBase.white, 0.95), 12.0, -5.0, -5.0)], pressedShade: OTint(OTintBase.black, 0.18)),
    'pillow.light.soft': ORecipeToken(sheen: [OTint(OTintBase.white, 0.1), OTint(OTintBase.black, 0.03)], sheenOnWhite: [OTint(OTintBase.white, 0.0), OTint(OTintBase.black, 0.03)], shadows: [OShadowToken(OTint(OTintBase.black, 0.112), 9.8, 3.5, 3.5), OShadowToken(OTint(OTintBase.white, 0.95), 8.4, -3.5, -3.5)], pressedShade: OTint(OTintBase.black, 0.18)),
    'pillow.light.surface': ORecipeToken(fillCanvas: true, shadows: [OShadowToken(OTint(OTintBase.black, 0.08), 16.0, 4.0, 4.0), OShadowToken(OTint(OTintBase.white, 1.0), 16.0, -4.0, -4.0)]),
    'pillow.light.well': ORecipeToken(fillCanvas: true, insets: [OShadowToken(OTint(OTintBase.black, 0.1), 4.0, 2.0, 2.0), OShadowToken(OTint(OTintBase.white, 0.9), 4.0, -2.0, -2.0)]),
    'pillow.dark.strong': ORecipeToken(sheen: [OTint(OTintBase.white, 0.16), OTint(OTintBase.black, 0.1)], shadows: [OShadowToken(OTint(OTintBase.black, 0.6), 14.0, 5.0, 5.0), OShadowToken(OTint(OTintBase.white, 0.05), 12.0, -5.0, -5.0)], pressedShade: OTint(OTintBase.black, 0.55)),
    'pillow.dark.soft': ORecipeToken(sheen: [OTint(OTintBase.white, 0.1), OTint(OTintBase.black, 0.03)], sheenOnWhite: [OTint(OTintBase.white, 0.0), OTint(OTintBase.black, 0.03)], shadows: [OShadowToken(OTint(OTintBase.black, 0.42), 9.8, 3.5, 3.5), OShadowToken(OTint(OTintBase.white, 0.05), 8.4, -3.5, -3.5)], pressedShade: OTint(OTintBase.black, 0.55)),
    'pillow.dark.surface': ORecipeToken(fillCanvas: true, shadows: [OShadowToken(OTint(OTintBase.black, 0.45), 16.0, 4.0, 4.0), OShadowToken(OTint(OTintBase.white, 0.03), 16.0, -4.0, -4.0)]),
    'pillow.dark.well': ORecipeToken(fillCanvas: true, insets: [OShadowToken(OTint(OTintBase.black, 0.5), 4.0, 2.0, 2.0), OShadowToken(OTint(OTintBase.white, 0.04), 4.0, -2.0, -2.0)]),
    'glass.light.strong': ORecipeToken(fillAlpha: 0.92, sheen: [OTint(OTintBase.white, 0.3), OTint(OTintBase.white, 0.0)], sheenStops: [0.0, 0.55], rim: OTint(OTintBase.white, 0.35), shadows: [OShadowToken(OTint(OTintBase.black, 0.18), 18.0, 6.0)]),
    'glass.light.soft': ORecipeToken(fillAlpha: 0.62, sheen: [OTint(OTintBase.white, 0.45), OTint(OTintBase.white, 0.0)], sheenStops: [0.0, 0.55], rim: OTint(OTintBase.white, 0.8), shadows: [OShadowToken(OTint(OTintBase.black, 0.07), 18.0, 6.0)]),
    'glass.light.surface': ORecipeToken(fillAlpha: 0.6, sheen: [OTint(OTintBase.white, 0.5), OTint(OTintBase.white, 0.0)], sheenStops: [0.0, 0.5], rim: OTint(OTintBase.white, 0.9), shadows: [OShadowToken(OTint(OTintBase.black, 0.05), 24.0, 8.0)]),
    'glass.light.well': ORecipeToken(fillAlpha: 0.5, rim: OTint(OTintBase.white, 0.6), insets: [OShadowToken(OTint(OTintBase.black, 0.05), 3.0, 1.0)]),
    'glass.dark.strong': ORecipeToken(fillAlpha: 0.92, sheen: [OTint(OTintBase.white, 0.3), OTint(OTintBase.white, 0.0)], sheenStops: [0.0, 0.55], rim: OTint(OTintBase.white, 0.22), shadows: [OShadowToken(OTint(OTintBase.black, 0.4), 18.0, 6.0)]),
    'glass.dark.soft': ORecipeToken(fillAlpha: 0.62, sheen: [OTint(OTintBase.white, 0.1), OTint(OTintBase.white, 0.0)], sheenStops: [0.0, 0.55], rim: OTint(OTintBase.white, 0.12), shadows: [OShadowToken(OTint(OTintBase.black, 0.22), 18.0, 6.0)]),
    'glass.dark.surface': ORecipeToken(fillAlpha: 0.55, sheen: [OTint(OTintBase.white, 0.06), OTint(OTintBase.white, 0.0)], sheenStops: [0.0, 0.5], rim: OTint(OTintBase.white, 0.08), shadows: [OShadowToken(OTint(OTintBase.black, 0.3), 24.0, 8.0)]),
    'glass.dark.well': ORecipeToken(fillAlpha: 0.5, rim: OTint(OTintBase.white, 0.05), insets: [OShadowToken(OTint(OTintBase.black, 0.3), 3.0, 1.0)]),
    'glow.light.strong': ORecipeToken(sheen: [OTint(OTintBase.white, 0.16), OTint(OTintBase.white, 0.0)], highlight: OTint(OTintBase.white, 0.3), shadows: [OShadowToken(OTint(OTintBase.glow, 0.3), 16.0, 6.0), OShadowToken(OTint(OTintBase.black, 0.12), 2.0, 1.0)]),
    'glow.light.soft': ORecipeToken(highlight: OTint(OTintBase.white, 0.6), rim: OTint(OTintBase.accent, 0.18), shadows: [OShadowToken(OTint(OTintBase.accent, 0.1), 14.0, 4.0)]),
    'glow.light.surface': ORecipeToken(rim: OTint(OTintBase.accent, 0.12), shadows: [OShadowToken(OTint(OTintBase.accent, 0.08), 26.0, 8.0)]),
    'glow.light.well': ORecipeToken(rim: OTint(OTintBase.accent, 0.1), insets: [OShadowToken(OTint(OTintBase.black, 0.05), 3.0, 1.0)]),
    'glow.dark.strong': ORecipeToken(sheen: [OTint(OTintBase.white, 0.16), OTint(OTintBase.white, 0.0)], highlight: OTint(OTintBase.white, 0.3), shadows: [OShadowToken(OTint(OTintBase.glow, 0.45), 22.0, 6.0), OShadowToken(OTint(OTintBase.glow, 0.3), 4.0, 1.0)]),
    'glow.dark.soft': ORecipeToken(highlight: OTint(OTintBase.white, 0.06), rim: OTint(OTintBase.accent, 0.22), shadows: [OShadowToken(OTint(OTintBase.accent, 0.2), 14.0, 4.0)]),
    'glow.dark.surface': ORecipeToken(rim: OTint(OTintBase.accent, 0.16), shadows: [OShadowToken(OTint(OTintBase.accent, 0.12), 26.0, 8.0)]),
    'glow.dark.well': ORecipeToken(rim: OTint(OTintBase.accent, 0.1), insets: [OShadowToken(OTint(OTintBase.black, 0.35), 3.0, 1.0)]),
  };
  /// Keyed '<finish>.<light|dark>'; only glass and glow have washes.
  static const washes = <String, List<OWashToken>>{
    'glass.light': [OWashToken(0.1, 0.1, false, 0.8, null, 0.16), OWashToken(0.95, 0.55, false, 0.85, Color(0xFF8B5CF6), 0.12)],
    'glass.dark': [OWashToken(0.1, 0.1, false, 0.8, null, 0.22), OWashToken(0.95, 0.55, false, 0.85, Color(0xFF8B5CF6), 0.18)],
    'glow.light': [OWashToken(0.5, -0.15, true, 1.1, null, 0.1)],
    'glow.dark': [OWashToken(0.5, -0.15, true, 1.1, null, 0.2)],
  };
}
