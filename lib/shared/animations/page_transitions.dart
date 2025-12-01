import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Premium page transitions for NovaTV
/// Inspired by Apple TV+ and Netflix smooth animations

/// Fade through transition - modern Material 3 style
class FadeThroughTransition extends CustomTransitionPage<void> {
  FadeThroughTransition({
    required super.child,
    super.key,
  }) : super(
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                reverseCurve: const Interval(0.5, 1.0, curve: Curves.easeIn),
              ),
              child: FadeTransition(
                opacity: ReverseAnimation(
                  CurvedAnimation(
                    parent: secondaryAnimation,
                    curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
                  ),
                ),
                child: child,
              ),
            );
          },
        );
}

/// Shared axis transition - horizontal slide with fade
class SharedAxisHorizontalTransition extends CustomTransitionPage<void> {
  SharedAxisHorizontalTransition({
    required super.child,
    super.key,
  }) : super(
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.1, 0.0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
                  ),
                ),
                child: child,
              ),
            );
          },
        );
}

/// Zoom fade transition - for modal-like content
class ZoomFadeTransition extends CustomTransitionPage<void> {
  ZoomFadeTransition({
    required super.child,
    super.key,
  }) : super(
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
              child: FadeTransition(
                opacity: curvedAnimation,
                child: child,
              ),
            );
          },
        );
}

/// Cinematic slide up transition - for player screen
/// Slides up smoothly on enter, shrinks to bottom-right on exit (for PiP minimize)
class CinematicSlideUpTransition extends CustomTransitionPage<void> {
  CinematicSlideUpTransition({
    required super.child,
    super.key,
  }) : super(
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Different behavior for enter vs exit
            final isForward = animation.status == AnimationStatus.forward ||
                animation.status == AnimationStatus.completed;

            if (isForward) {
              // Enter: Slide up with fade
              final curvedAnimation = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutQuart,
              );

              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.05),
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
                    ),
                  ),
                  child: Container(
                    color: Colors.black,
                    child: child,
                  ),
                ),
              );
            } else {
              // Exit: Shrink and slide toward bottom-right (where mini player appears)
              final curvedAnimation = CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubic,
              );

              return AnimatedBuilder(
                animation: curvedAnimation,
                builder: (context, child) {
                  // Scale from 1.0 down to 0.3
                  final scale = 0.3 + (0.7 * curvedAnimation.value);
                  // Slide toward bottom-right as it shrinks
                  final dx = 0.4 * (1 - curvedAnimation.value);
                  final dy = 0.4 * (1 - curvedAnimation.value);

                  return Transform(
                    alignment: Alignment.bottomRight,
                    transform: Matrix4.identity()
                      ..translate(
                        dx * MediaQuery.of(context).size.width,
                        dy * MediaQuery.of(context).size.height,
                      )
                      ..scale(scale),
                    child: Opacity(
                      opacity: curvedAnimation.value.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  color: Colors.black,
                  child: child,
                ),
              );
            }
          },
        );
}

/// Fade scale transition - subtle and elegant
class FadeScaleTransition extends CustomTransitionPage<void> {
  FadeScaleTransition({
    required super.child,
    super.key,
  }) : super(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              ),
            );
          },
        );
}
