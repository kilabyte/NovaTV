import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════════════
// AURORA MESH BACKGROUND
// Animated gradient that creates the macOS Tahoe aurora effect
// ═══════════════════════════════════════════════════════════════════════════

class AuroraBackground extends StatefulWidget {
  final Widget child;
  final bool animate;
  final double intensity;

  const AuroraBackground({
    super.key,
    required this.child,
    this.animate = true,
    this.intensity = 0.4,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base dark background
        Container(color: AppColors.darkBase),

        // Animated aurora blobs
        if (widget.animate)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _AuroraPainter(
                animation: _controller.value,
                intensity: widget.intensity,
              ),
              size: Size.infinite,
            ),
          )
        else
          CustomPaint(
            painter: _AuroraPainter(
              animation: 0.0,
              intensity: widget.intensity,
            ),
            size: Size.infinite,
          ),

        // Content
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double animation;
  final double intensity;

  _AuroraPainter({required this.animation, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..blendMode = BlendMode.screen;

    // Cyan blob (top-left area)
    final cyanCenter = Offset(
      size.width * (0.2 + 0.1 * math.sin(animation * math.pi * 2)),
      size.height * (0.3 + 0.1 * math.cos(animation * math.pi * 2)),
    );
    paint.shader = RadialGradient(
      colors: [
        AppColors.auroraCyan.withValues(alpha: intensity * 0.5),
        AppColors.auroraCyan.withValues(alpha: intensity * 0.2),
        AppColors.auroraCyan.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.4, 1.0],
    ).createShader(Rect.fromCircle(center: cyanCenter, radius: size.width * 0.5));
    canvas.drawCircle(cyanCenter, size.width * 0.5, paint);

    // Purple blob (center-right area)
    final purpleCenter = Offset(
      size.width * (0.7 + 0.1 * math.cos(animation * math.pi * 2 + 1)),
      size.height * (0.4 + 0.15 * math.sin(animation * math.pi * 2 + 1)),
    );
    paint.shader = RadialGradient(
      colors: [
        AppColors.auroraPurple.withValues(alpha: intensity * 0.4),
        AppColors.auroraPurple.withValues(alpha: intensity * 0.15),
        AppColors.auroraPurple.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.4, 1.0],
    ).createShader(Rect.fromCircle(center: purpleCenter, radius: size.width * 0.45));
    canvas.drawCircle(purpleCenter, size.width * 0.45, paint);

    // Magenta blob (bottom area)
    final magentaCenter = Offset(
      size.width * (0.5 + 0.15 * math.sin(animation * math.pi * 2 + 2)),
      size.height * (0.8 + 0.1 * math.cos(animation * math.pi * 2 + 2)),
    );
    paint.shader = RadialGradient(
      colors: [
        AppColors.auroraMagenta.withValues(alpha: intensity * 0.3),
        AppColors.auroraMagenta.withValues(alpha: intensity * 0.1),
        AppColors.auroraMagenta.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.4, 1.0],
    ).createShader(Rect.fromCircle(center: magentaCenter, radius: size.width * 0.4));
    canvas.drawCircle(magentaCenter, size.width * 0.4, paint);
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) =>
      animation != oldDelegate.animation || intensity != oldDelegate.intensity;
}

// ═══════════════════════════════════════════════════════════════════════════
// GLASS CARD
// Frosted glass panel with blur and luminous border
// ═══════════════════════════════════════════════════════════════════════════

class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? tintColor;
  final bool showBorder;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 20.0,
    this.opacity = 0.1,
    this.borderRadius = 16.0,
    this.padding,
    this.margin,
    this.tintColor,
    this.showBorder = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (tintColor ?? Colors.white).withValues(alpha: opacity + 0.05),
                (tintColor ?? Colors.white).withValues(alpha: opacity),
              ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: showBorder
                ? Border.all(
                    color: AppColors.glassBorder,
                    width: 1,
                  )
                : null,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            child: card,
          ),
        ),
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: card,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GLASS BUTTON
// Frosted glass button with glow effect on hover/press
// ═══════════════════════════════════════════════════════════════════════════

class GlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? accentColor;
  final bool isActive;

  const GlassButton({
    super.key,
    required this.child,
    this.onPressed,
    this.blur = 15.0,
    this.borderRadius = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.accentColor,
    this.isActive = false,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppColors.primary;
    final isHighlighted = _isHovered || _isPressed || widget.isActive;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: widget.blur,
                sigmaY: widget.blur,
              ),
              child: Container(
                padding: widget.padding,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isHighlighted
                        ? [
                            accent.withValues(alpha: 0.3),
                            accent.withValues(alpha: 0.15),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.white.withValues(alpha: 0.08),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(
                    color: isHighlighted
                        ? accent.withValues(alpha: 0.5)
                        : AppColors.glassBorder,
                    width: 1,
                  ),
                  boxShadow: isHighlighted
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: -5,
                          ),
                        ]
                      : null,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GLASS ICON BUTTON
// Circular glass button for icons
// ═══════════════════════════════════════════════════════════════════════════

class GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final Color? accentColor;
  final bool isActive;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44.0,
    this.color,
    this.accentColor,
    this.isActive = false,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppColors.primary;
    final isHighlighted = _isHovered || widget.isActive;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.size,
          height: widget.size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.size / 2),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isHighlighted
                        ? [
                            accent.withValues(alpha: 0.3),
                            accent.withValues(alpha: 0.15),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.06),
                          ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isHighlighted
                        ? accent.withValues(alpha: 0.4)
                        : AppColors.glassBorder,
                    width: 1,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  color: isHighlighted
                      ? accent
                      : widget.color ?? AppColors.darkOnSurface,
                  size: widget.size * 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GLASS CHIP
// Small glass pill for tags, filters, etc.
// ═══════════════════════════════════════════════════════════════════════════

class GlassChip extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? accentColor;

  const GlassChip({
    super.key,
    required this.label,
    this.icon,
    this.isSelected = false,
    this.onTap,
    this.accentColor,
  });

  @override
  State<GlassChip> createState() => _GlassChipState();
}

class _GlassChipState extends State<GlassChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppColors.primary;
    final isHighlighted = _isHovered || widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isHighlighted
                        ? [
                            accent.withValues(alpha: 0.35),
                            accent.withValues(alpha: 0.2),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.06),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isHighlighted
                        ? accent.withValues(alpha: 0.5)
                        : AppColors.glassBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        size: 16,
                        color: isHighlighted ? accent : AppColors.darkOnSurface,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isHighlighted ? accent : AppColors.darkOnSurface,
                      ),
                    ),
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

// ═══════════════════════════════════════════════════════════════════════════
// GLASS SEARCH BAR
// Frosted glass search input
// ═══════════════════════════════════════════════════════════════════════════

class GlassSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const GlassSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(
              color: AppColors.darkOnSurface,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: AppColors.darkOnSurfaceMuted,
                fontSize: 15,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.darkOnSurfaceVariant,
              ),
              suffixIcon: controller?.text.isNotEmpty == true
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: onClear,
                      color: AppColors.darkOnSurfaceVariant,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GLOW CONTAINER
// Container with colored glow effect
// ═══════════════════════════════════════════════════════════════════════════

class GlowContainer extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double glowRadius;
  final double glowSpread;

  const GlowContainer({
    super.key,
    required this.child,
    this.glowColor = AppColors.primary,
    this.glowRadius = 30.0,
    this.glowSpread = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.4),
            blurRadius: glowRadius,
            spreadRadius: glowSpread,
          ),
        ],
      ),
      child: child,
    );
  }
}
