import 'package:flutter/material.dart';

/// Premium staggered animations for list items
/// Creates smooth, cascading entrance effects

/// Staggered fade slide animation for list items
class StaggeredFadeSlide extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;
  final Curve curve;

  const StaggeredFadeSlide({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 400),
    this.beginOffset = const Offset(0.0, 0.05),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<StaggeredFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    // Start animation with staggered delay
    Future.delayed(widget.delay * widget.index, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Staggered scale animation for grid items
class StaggeredScale extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final double beginScale;
  final Curve curve;

  const StaggeredScale({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 40),
    this.duration = const Duration(milliseconds: 350),
    this.beginScale = 0.8,
    this.curve = Curves.easeOutBack,
  });

  @override
  State<StaggeredScale> createState() => _StaggeredScaleState();
}

class _StaggeredScaleState extends State<StaggeredScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: widget.beginScale,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    // Start animation with staggered delay
    Future.delayed(widget.delay * widget.index, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Animated list wrapper that handles entrance animations
class AnimatedListWrapper extends StatelessWidget {
  final List<Widget> children;
  final Duration itemDelay;
  final Duration itemDuration;
  final bool useScale;

  const AnimatedListWrapper({
    super.key,
    required this.children,
    this.itemDelay = const Duration(milliseconds: 50),
    this.itemDuration = const Duration(milliseconds: 400),
    this.useScale = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(children.length, (index) {
        if (useScale) {
          return StaggeredScale(
            index: index,
            delay: itemDelay,
            duration: itemDuration,
            child: children[index],
          );
        }
        return StaggeredFadeSlide(
          index: index,
          delay: itemDelay,
          duration: itemDuration,
          child: children[index],
        );
      }),
    );
  }
}

/// Extension for easy staggered animation on any widget
extension StaggeredAnimationExtension on Widget {
  Widget withStaggeredFadeSlide({
    required int index,
    Duration delay = const Duration(milliseconds: 50),
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return StaggeredFadeSlide(
      index: index,
      delay: delay,
      duration: duration,
      child: this,
    );
  }

  Widget withStaggeredScale({
    required int index,
    Duration delay = const Duration(milliseconds: 40),
    Duration duration = const Duration(milliseconds: 350),
  }) {
    return StaggeredScale(
      index: index,
      delay: delay,
      duration: duration,
      child: this,
    );
  }
}
