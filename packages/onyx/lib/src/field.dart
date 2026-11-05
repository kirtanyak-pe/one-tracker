import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';
import 'tokens.dart';

/// A text field on a raised fill. Built on [EditableText] with Onyx's own
/// selection handles and copy/paste menu.
class OField extends StatefulWidget {
  const OField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.placeholder,
    this.prefixIcon,
    this.prefixText,
    this.suffix,
    this.error,
    this.helper,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofocus = false,
    this.autocorrect = true,
    this.obscure = false,
    this.enabled = true,
    this.minLines,
    this.maxLines = 1,
    this.style,
    this.textAlign = TextAlign.start,
    this.bare = false,
    this.autofillHints,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Small label above the field.
  final String? label;
  final String? placeholder;
  final IconData? prefixIcon;
  final String? prefixText;
  final Widget? suffix;

  /// Replaces [helper] and outlines the field in the negative colour.
  final String? error;
  final String? helper;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final bool autocorrect;
  final bool obscure;
  final bool enabled;
  final int? minLines;
  final int? maxLines;
  final TextStyle? style;
  final TextAlign textAlign;

  /// No fill, no padding: the text alone (big amount inputs).
  final bool bare;
  final Iterable<String>? autofillHints;

  @override
  State<OField> createState() => _OFieldState();
}

class _OFieldState extends State<OField> implements TextSelectionGestureDetectorBuilderDelegate {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;
  late final _builder = TextSelectionGestureDetectorBuilder(delegate: this);

  TextEditingController get _controller => widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  final GlobalKey<EditableTextState> editableTextKey = GlobalKey<EditableTextState>();

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => widget.enabled;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_rebuild);
    _controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(OField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_rebuild);
      _focus.addListener(_rebuild);
    }
    if (old.controller != widget.controller) {
      (old.controller ?? _ownController)?.removeListener(_rebuild);
      _controller.addListener(_rebuild);
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_rebuild);
    _controller.removeListener(_rebuild);
    _ownController?.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final style = (widget.style ?? t.body.copyWith(fontSize: 16)).copyWith(color: widget.style?.color ?? c.ink);
    final focused = _focus.hasFocus;
    final hasError = widget.error != null;

    final editable = EditableText(
      key: editableTextKey,
      controller: _controller,
      focusNode: _focus,
      readOnly: !widget.enabled,
      style: style,
      strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: widget.maxLines == 1),
      textAlign: widget.textAlign,
      cursorColor: c.accent,
      cursorWidth: 2,
      cursorRadius: const Radius.circular(2),
      cursorOpacityAnimates: true,
      backgroundCursorColor: c.inkFaint,
      selectionColor: c.accent.withValues(alpha: 0.25),
      selectionControls: widget.enabled ? oSelectionControls : null,
      contextMenuBuilder: widget.enabled ? _menu : null,
      enableInteractiveSelection: widget.enabled,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      autofocus: widget.autofocus,
      autocorrect: widget.autocorrect,
      obscureText: widget.obscure,
      minLines: widget.minLines,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      keyboardAppearance: context.onyx.brightness,
      rendererIgnoresPointer: true,
      scrollPadding: const EdgeInsets.all(OSpace.huge + OSpace.huge),
      onTapOutside: (_) => _focus.unfocus(),
    );

    final placeholder = widget.placeholder != null && _controller.text.isEmpty
        ? IgnorePointer(
            child: Text(
              widget.placeholder!,
              style: style.copyWith(color: c.inkFaint),
              textAlign: widget.textAlign,
              maxLines: widget.maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          )
        : null;

    final textArea = Stack(
      alignment: switch (widget.textAlign) {
        TextAlign.center => Alignment.center,
        TextAlign.right || TextAlign.end => Alignment.centerRight,
        _ => Alignment.centerLeft,
      },
      children: [?placeholder, editable],
    );

    Widget field = _builder.buildGestureDetector(behavior: HitTestBehavior.translucent, child: textArea);

    if (!widget.bare) {
      field = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? _focus.requestFocus : null,
        child: AnimatedContainer(
          duration: OMotion.of(context, OMotion.fast),
          constraints: const BoxConstraints(minHeight: 52),
          padding: EdgeInsets.fromLTRB(widget.prefixIcon != null ? 14 : 16, 0, widget.suffix != null ? 4 : 16, 0),
          decoration: ShapeDecoration(
            color: focused ? c.surface : c.raised,
            shape: ORadius.smooth(
              ORadius.md,
              side: BorderSide(
                color: hasError ? c.negative : (focused ? c.ink : c.raised),
                width: focused || hasError ? 1.5 : 1,
              ),
            ),
          ),
          child: Row(
            children: [
              if (widget.prefixIcon != null) ...[
                Icon(widget.prefixIcon, size: 18, color: focused ? c.ink : c.inkSoft),
                const SizedBox(width: 10),
              ],
              if (widget.prefixText != null) Text(widget.prefixText!, style: style.copyWith(color: c.inkSoft)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: widget.maxLines == 1 ? 0 : 14),
                  child: field,
                ),
              ),
              if (widget.suffix != null)
                IconTheme.merge(
                  data: IconThemeData(color: c.inkSoft, size: 18),
                  child: widget.suffix!,
                ),
            ],
          ),
        ),
      );
    }

    final below = widget.error ?? widget.helper;
    if (widget.label == null && below == null) return Opacity(opacity: widget.enabled ? 1 : 0.5, child: field);
    return Opacity(
      opacity: widget.enabled ? 1 : 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) ...[
            Text(widget.label!, style: t.smallStrong.tint(c.inkSoft)),
            const SizedBox(height: OSpace.sm),
          ],
          field,
          if (below != null) ...[
            const SizedBox(height: 6),
            Text(below, style: t.caption.tint(hasError ? c.negative : c.inkSoft)),
          ],
        ],
      ),
    );
  }

  Widget _menu(BuildContext context, EditableTextState state) =>
      OTextMenu(anchors: state.contextMenuAnchors, items: state.contextMenuButtonItems, theme: OTheme.of(context));
}

/// The cut/copy/paste bar: a dark capsule above the selection.
class OTextMenu extends StatelessWidget {
  const OTextMenu({super.key, required this.anchors, required this.items, required this.theme});

  final TextSelectionToolbarAnchors anchors;
  final List<ContextMenuButtonItem> items;
  final OThemeData theme;

  static String _label(ContextMenuButtonItem i) =>
      i.label ??
      switch (i.type) {
        ContextMenuButtonType.cut => 'Cut',
        ContextMenuButtonType.copy => 'Copy',
        ContextMenuButtonType.paste => 'Paste',
        ContextMenuButtonType.selectAll => 'Select all',
        ContextMenuButtonType.delete => 'Delete',
        ContextMenuButtonType.lookUp => 'Look up',
        ContextMenuButtonType.searchWeb => 'Search',
        ContextMenuButtonType.share => 'Share',
        ContextMenuButtonType.liveTextInput => 'Scan text',
        ContextMenuButtonType.custom => '',
      };

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    const fg = Color(0xFFF2F5F9);
    final pad = MediaQuery.paddingOf(context);
    final above = anchors.primaryAnchor - const Offset(0, 10);
    final below = (anchors.secondaryAnchor ?? anchors.primaryAnchor) + const Offset(0, 28);
    return Padding(
      padding: EdgeInsets.fromLTRB(8, pad.top + 8, 8, 8),
      child: CustomSingleChildLayout(
        delegate: TextSelectionToolbarLayoutDelegate(
          anchorAbove: above - Offset(8, pad.top + 8),
          anchorBelow: below - Offset(8, pad.top + 8),
          fitsAbove: above.dy - pad.top - 8 > 44,
        ),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: ShapeDecoration(
            color: const Color(0xFF1A1E25),
            shape: const StadiumBorder(),
            shadows: OShadow.floating(Brightness.light),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, item) in items.indexed) ...[
                if (i > 0) Container(width: 1, height: 16, color: fg.withValues(alpha: 0.15)),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: item.onPressed,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(child: Text(_label(item), style: theme.type.smallStrong.tint(fg))),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Round accent handles for text selection.
final TextSelectionControls oSelectionControls = _OSelectionControls();

class _OSelectionControls extends TextSelectionControls with TextSelectionHandleControls {
  static const _size = 18.0;

  @override
  Size getHandleSize(double textLineHeight) => const Size(_size, _size);

  @override
  Widget buildHandle(BuildContext context, TextSelectionHandleType type, double textLineHeight, [VoidCallback? onTap]) {
    final color = OTheme.of(context).colors.accent;
    final handle = SizedBox(
      width: _size,
      height: _size,
      child: CustomPaint(painter: _HandlePainter(color, type)),
    );
    return handle;
  }

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) => switch (type) {
    TextSelectionHandleType.left => const Offset(_size, 0),
    TextSelectionHandleType.right => Offset.zero,
    TextSelectionHandleType.collapsed => const Offset(_size / 2, 0),
  };
}

/// A teardrop: a circle with one square corner pointing at the text.
class _HandlePainter extends CustomPainter {
  _HandlePainter(this.color, this.type);
  final Color color;
  final TextSelectionHandleType type;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final r = Radius.circular(size.width / 2);
    final rect = Offset.zero & size;
    switch (type) {
      case TextSelectionHandleType.left:
        canvas.drawRRect(RRect.fromRectAndCorners(rect, topLeft: r, bottomLeft: r, bottomRight: r), paint);
      case TextSelectionHandleType.right:
        canvas.drawRRect(RRect.fromRectAndCorners(rect, topRight: r, bottomLeft: r, bottomRight: r), paint);
      case TextSelectionHandleType.collapsed:
        // A drop hanging from the cursor.
        canvas.drawCircle(rect.center + const Offset(0, 2), size.width / 2 - 1, paint);
        canvas.drawRect(Rect.fromLTWH(size.width / 2 - 1, 0, 2, size.height / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_HandlePainter old) => old.color != color || old.type != type;
}
