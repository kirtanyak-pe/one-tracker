import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'button.dart';
import 'theme.dart';
import 'tokens.dart';

/// Opens a bottom sheet: a surface that rises from the bottom over a scrim,
/// with a grab handle, dismissed by a tap outside or a downward drag.
Future<T?> showOSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
  bool useRootNavigator = true,
}) => Navigator.of(
  context,
  rootNavigator: useRootNavigator,
).push<T>(_SheetRoute<T>(builder: builder, dismissible: dismissible, theme: OTheme.of(context)));

class _SheetRoute<T> extends PopupRoute<T> {
  _SheetRoute({required this.builder, required this.dismissible, required this.theme});

  final WidgetBuilder builder;
  final bool dismissible;
  final OThemeData theme;

  @override
  Color? get barrierColor => theme.colors.scrim;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => OTheme(
    data: theme,
    child: _Sheet(
      route: this,
      child: Builder(builder: builder),
    ),
  );
}

class _Sheet extends StatefulWidget {
  const _Sheet({required this.route, required this.child});

  final _SheetRoute route;
  final Widget child;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  final _key = GlobalKey();
  double _drag = 0;

  double get _height => (_key.currentContext?.size?.height ?? 400);

  void _update(DragUpdateDetails d) {
    if (!widget.route.dismissible) return;
    setState(() => _drag = (_drag + d.delta.dy).clamp(0, double.infinity));
  }

  void _end(DragEndDetails d) {
    if (!widget.route.dismissible) return;
    final v = d.primaryVelocity ?? 0;
    if (v > 700 || _drag > _height * 0.35) {
      Navigator.of(context).pop();
    } else {
      setState(() => _drag = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mq = MediaQuery.of(context);
    final a = CurvedAnimation(parent: widget.route.animation!, curve: OMotion.emphasized, reverseCurve: OMotion.exit);
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedBuilder(
        animation: a,
        builder: (context, child) => FractionalTranslation(translation: Offset(0, 1 - a.value), child: child),
        child: AnimatedContainer(
          duration: _drag == 0 ? OMotion.base : Duration.zero,
          curve: OMotion.standard,
          transform: Matrix4.translationValues(0, _drag, 0),
          child: GestureDetector(
            onVerticalDragUpdate: _update,
            onVerticalDragEnd: _end,
            child: ConstrainedBox(
              key: _key,
              constraints: BoxConstraints(maxHeight: mq.size.height - mq.padding.top - OSpace.xxl, maxWidth: 640),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: c.surface,
                  shape: const RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(ORadius.xl)),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: OSpace.sm),
                      Container(
                        width: 36,
                        height: 4,
                        decoration: ShapeDecoration(color: c.lineStrong, shape: const StadiumBorder()),
                      ),
                      Flexible(
                        child: MediaQuery.removeViewInsets(
                          context: context,
                          removeBottom: true,
                          child: SafeArea(top: false, child: widget.child),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A sheet's standard layout: a title, an optional subtitle, the body and
/// actions, all with the page gutter.
class OSheetBody extends StatelessWidget {
  const OSheetBody({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.actions = const [],
    this.scroll = true,
  });

  final String? title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.lg, OSpace.gutter, OSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) Text(title!, style: context.type.title2),
          if (subtitle != null) ...[const SizedBox(height: OSpace.xs + 2), Text(subtitle!, style: context.type.small)],
          if (title != null || subtitle != null) const SizedBox(height: OSpace.xl),
          child,
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(child: scroll ? SingleChildScrollView(child: body) : body),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(OSpace.gutter, 0, OSpace.gutter, OSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(height: OSpace.sm), actions[i]],
              ],
            ),
          ),
      ],
    );
  }
}

/// A centred dialog that fades and scales in over a blurred scrim.
Future<T?> showODialog<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) {
  final theme = OTheme.of(context);
  return Navigator.of(context, rootNavigator: true).push<T>(
    RawDialogRoute<T>(
      barrierDismissible: dismissible,
      barrierLabel: 'Dismiss',
      barrierColor: theme.colors.scrim,
      transitionDuration: OMotion.base,
      pageBuilder: (context, _, _) => OTheme(
        data: theme,
        child: Builder(builder: builder),
      ),
      transitionBuilder: (context, a, _, child) {
        final curved = CurvedAnimation(parent: a, curve: OMotion.emphasized, reverseCurve: OMotion.exit);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6 * a.value, sigmaY: 6 * a.value),
          child: FadeTransition(
            opacity: curved,
            child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(curved), child: child),
          ),
        );
      },
    ),
  );
}

/// A dialog's card: title, message or content, and actions laid out as
/// full-width stacked pills (primary first).
class ODialog extends StatelessWidget {
  const ODialog({super.key, required this.title, this.message, this.content, this.actions = const [], this.icon});

  final String title;
  final String? message;
  final Widget? content;
  final List<Widget> actions;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mq = MediaQuery.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(OSpace.xxl, OSpace.xxl, OSpace.xxl, OSpace.xxl + mq.viewInsets.bottom),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(OSpace.xxl),
              decoration: ShapeDecoration(
                color: c.surface,
                shape: ORadius.smooth(ORadius.xl),
                shadows: OShadow.floating(context.onyx.brightness),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (icon != null) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: ShapeDecoration(color: c.raised, shape: ORadius.smooth(ORadius.sm)),
                          child: Icon(icon, size: 22, color: c.ink),
                        ),
                      ),
                      const SizedBox(height: OSpace.lg),
                    ],
                    Text(title, style: context.type.title3.copyWith(fontSize: 19)),
                    if (message != null) ...[
                      const SizedBox(height: OSpace.sm),
                      Text(message!, style: context.type.body.tint(c.inkSoft)),
                    ],
                    if (content != null) ...[const SizedBox(height: OSpace.lg), content!],
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: OSpace.xxl),
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: OSpace.sm),
                        actions[i],
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks a yes/no question. Resolves true on confirm, false otherwise.
Future<bool> showOConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirm = 'Confirm',
  String cancel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final ok = await showODialog<bool>(
    context,
    builder: (context) => ODialog(
      title: title,
      message: message,
      icon: icon,
      actions: [
        OButton(
          label: confirm,
          expand: true,
          variant: destructive ? OButtonVariant.danger : OButtonVariant.primary,
          onPressed: () {
            if (destructive) HapticFeedback.mediumImpact();
            Navigator.pop(context, true);
          },
        ),
        OButton.ghost(label: cancel, expand: true, onPressed: () => Navigator.pop(context, false)),
      ],
    ),
  );
  return ok ?? false;
}

/// Tap (or long-press) [child] to show [message] in a dark bubble above it.
class OTooltip extends StatefulWidget {
  const OTooltip({super.key, required this.message, required this.child, this.tapToShow = false});

  final String message;
  final Widget child;

  /// Show on tap instead of long-press (for info pills that do nothing else).
  final bool tapToShow;

  @override
  State<OTooltip> createState() => _OTooltipState();
}

class _OTooltipState extends State<OTooltip> with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  late final _fade = AnimationController(vsync: this, duration: OMotion.fast);

  void _show() {
    HapticFeedback.selectionClick();
    _portal.show();
    _fade.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 2600), _hide);
  }

  void _hide() {
    if (!mounted) return;
    _fade.reverse().whenComplete(() {
      if (mounted && _fade.isDismissed) _portal.hide();
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = OTheme.of(context);
    return Semantics(
      tooltip: widget.message,
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (_) => Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(behavior: HitTestBehavior.translucent, onTapDown: (_) => _hide()),
              ),
              CompositedTransformFollower(
                link: _link,
                targetAnchor: Alignment.topCenter,
                followerAnchor: Alignment.bottomCenter,
                offset: const Offset(0, -8),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  widthFactor: 1,
                  heightFactor: 1,
                  child: FadeTransition(
                    opacity: _fade,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: ShapeDecoration(color: const Color(0xFF1C1C1F), shape: ORadius.smooth(ORadius.sm)),
                        child: Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: theme.type.caption.tint(const Color(0xFFF4F4F5)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.tapToShow ? _show : null,
            onLongPress: widget.tapToShow ? null : _show,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
