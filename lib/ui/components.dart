import 'package:flutter/widgets.dart';
import 'package:onyx/onyx.dart';

/// Label above a big value, optional caption and trailing visual.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.caption, this.trailing, this.onTap});

  final String label;
  final String value;
  final String? caption;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return OCard(
      onTap: onTap,
      padding: const EdgeInsets.all(OSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: type.small),
                const SizedBox(height: OSpace.sm),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: type.title1.copyWith(fontSize: 24).tabular),
                ),
                if (caption != null) ...[const SizedBox(height: OSpace.xs), Text(caption!, style: type.caption)],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Initials in a raised circle.
class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 40, this.ring});

  final String name;
  final double size;

  /// Border colour, for overlapping stacks.
  final Color? ring;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    // Two letters don't fit small circles.
    if (parts.length == 1 || size < 32) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return OFinishBox(
      color: c.raised,
      depth: ODepth.surface,
      shape: CircleBorder(side: ring == null ? BorderSide.none : BorderSide(color: ring!, width: 2)),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        child: Text(
          _initials,
          style: context.type.small.copyWith(fontSize: size * 0.36, fontWeight: FontWeight.w600, color: c.ink),
        ),
      ),
    );
  }
}

/// Overlapping avatars, "+n" after [max].
class AvatarStack extends StatelessWidget {
  const AvatarStack(this.names, {super.key, this.size = 28, this.max = 4});

  final List<String> names;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = names.take(max).toList();
    final extra = names.length - shown.length;
    final step = size * 0.7;
    final count = shown.length + (extra > 0 ? 1 : 0);
    return SizedBox(
      height: size,
      width: count == 0 ? 0 : step * (count - 1) + size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: step * i,
              child: Avatar(shown[i], size: size, ring: c.surface),
            ),
          if (extra > 0)
            Positioned(
              left: step * shown.length,
              child: Avatar('+ $extra', size: size, ring: c.surface),
            ),
        ],
      ),
    );
  }
}

/// Button label that shrinks instead of wrapping at large system font sizes.
class OneLineLabel extends StatelessWidget {
  const OneLineLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1, softWrap: false));
}
