import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme/app_colors.dart';

/// Wraps any tappable widget with D-pad-friendly focus behaviour for TV.
///
/// Renders a focus ring around the child when the widget is focused,
/// activates the [onTap] / [onLongPress] callbacks on Enter/Select/Space,
/// and is a no-op cosmetic on phone/touch input where the user never
/// gets focus on these elements.
///
/// Usage:
/// ```dart
/// TvFocusable(
///   onTap: () => goToChannel(),
///   child: ChannelCard(...),
/// )
/// ```
class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Border radius of the focus ring. Should match the wrapped widget's
  /// own corner radius for a tight visual fit.
  final double borderRadius;

  /// Padding between the focus ring and the child. Defaults to 0; set when
  /// the child has internal padding that the ring should sit outside of.
  final EdgeInsetsGeometry padding;

  /// Whether this focusable should grab focus on first build. Useful for
  /// the first item in a list so D-pad has a starting point.
  final bool autofocus;

  const TvFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = 8,
    this.padding = EdgeInsets.zero,
    this.autofocus = false,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA ||
            event.logicalKey == LogicalKeyboardKey.space) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: widget.padding,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: _focused ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.45),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
