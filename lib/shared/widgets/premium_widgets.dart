import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/theme/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════════════
// GLASSMORPHISM CONTAINER
// Frosted glass effect for overlays and cards
// ═══════════════════════════════════════════════════════════════════════════
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  const GlassContainer({super.key, required this.child, this.blur = 20, this.opacity = 0.1, this.borderRadius, this.border, this.padding, this.margin, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              borderRadius: borderRadius ?? BorderRadius.circular(16),
              border: border ?? Border.all(color: AppColors.glassBorder, width: 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GLOW CONTAINER
// Adds a subtle glow effect around widgets
// ═══════════════════════════════════════════════════════════════════════════
class GlowContainer extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double blurRadius;
  final double spreadRadius;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlowContainer({super.key, required this.child, this.glowColor = AppColors.primary, this.blurRadius = 20, this.spreadRadius = 0, this.borderRadius, this.padding, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: glowColor.withValues(alpha: 0.3), blurRadius: blurRadius, spreadRadius: spreadRadius)],
      ),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GRADIENT BORDER CONTAINER
// Premium gradient border effect
// ═══════════════════════════════════════════════════════════════════════════
class GradientBorderContainer extends StatelessWidget {
  final Widget child;
  final List<Color> gradientColors;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GradientBorderContainer({super.key, required this.child, this.gradientColors = AppColors.gradientPrimary, this.borderWidth = 2, this.borderRadius, this.backgroundColor, this.padding, this.margin});

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Container(
        margin: EdgeInsets.all(borderWidth),
        padding: padding,
        decoration: BoxDecoration(color: backgroundColor ?? AppColors.darkSurfaceVariant, borderRadius: BorderRadius.circular((radius.topLeft.x - borderWidth).clamp(0, double.infinity))),
        child: child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHIMMER LOADING WIDGET
// Premium loading animation
// ═══════════════════════════════════════════════════════════════════════════
class ShimmerWidget extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerWidget({super.key, required this.width, required this.height, this.borderRadius});

  @override
  State<ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<ShimmerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(begin: Alignment(_animation.value - 1, 0), end: Alignment(_animation.value + 1, 0), colors: const [AppColors.shimmerBase, AppColors.shimmerHighlight, AppColors.shimmerBase]),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM CHANNEL CARD
// Cinematic channel card with hover effects
// ═══════════════════════════════════════════════════════════════════════════
class PremiumChannelCard extends StatefulWidget {
  final String name;
  final String? logoUrl;
  final String? currentProgram;
  final bool isLive;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;

  const PremiumChannelCard({super.key, required this.name, this.logoUrl, this.currentProgram, this.isLive = false, this.isFavorite = false, this.onTap, this.onFavoriteTap});

  @override
  State<PremiumChannelCard> createState() => _PremiumChannelCardState();
}

class _PremiumChannelCardState extends State<PremiumChannelCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _isHovered ? AppColors.primary.withValues(alpha: 0.5) : AppColors.darkBorder, width: _isHovered ? 2 : 1),
              boxShadow: _isHovered ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 0)] : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Channel Logo Area
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      // Logo
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.darkSurface,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                        ),
                        child: widget.logoUrl != null
                            ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                child: Image.network(
                                  widget.logoUrl!,
                                  fit: BoxFit.contain,
                                  // Add caching for better performance
                                  cacheWidth: 200, // Limit image size for memory efficiency
                                  cacheHeight: 200,
                                  errorBuilder: (_, __, ___) => _buildPlaceholder(),
                                ),
                              )
                            : _buildPlaceholder(),
                      ),
                      // Live Badge
                      if (widget.isLive)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.live, borderRadius: BorderRadius.circular(4)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, size: 6, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'LIVE',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Favorite Button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: widget.onFavoriteTap,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: widget.isFavorite ? AppColors.secondary : AppColors.darkSurface.withValues(alpha: 0.8), shape: BoxShape.circle),
                            child: Icon(widget.isFavorite ? Icons.favorite : Icons.favorite_border, size: 16, color: widget.isFavorite ? Colors.black : Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Channel Info
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.darkOnSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.currentProgram != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.currentProgram!,
                            style: TextStyle(fontSize: 12, color: AppColors.primary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(child: Icon(Icons.tv, size: 40, color: AppColors.darkOnSurfaceMuted));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LIVE BADGE
// Animated live indicator
// ═══════════════════════════════════════════════════════════════════════════
class LiveBadge extends StatefulWidget {
  final double size;

  const LiveBadge({super.key, this.size = 12});

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.live, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: _animation.value),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GRADIENT TEXT
// Text with gradient fill
// ═══════════════════════════════════════════════════════════════════════════
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final List<Color> colors;
  final TextAlign? textAlign;

  const GradientText({super.key, required this.text, this.style, this.colors = AppColors.gradientPrimary, this.textAlign});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(bounds),
      child: Text(text, style: style, textAlign: textAlign),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION HEADER
// Premium section header with optional action
// ═══════════════════════════════════════════════════════════════════════════
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionTap;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.actionText, this.onActionTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          if (trailing != null)
            trailing!
          else if (actionText != null)
            TextButton(
              onPressed: onActionTap,
              style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionText!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios, size: 14),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
