import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../playlist/domain/entities/channel.dart';

/// Premium channel card with hover effects and glassmorphism
class ChannelCard extends StatefulWidget {
  final Channel channel;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onLongPress;

  const ChannelCard({super.key, required this.channel, required this.onTap, this.onFavorite, this.onLongPress});

  @override
  State<ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<ChannelCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    setState(() => _isHovered = isHovered);
    if (isHovered) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3 * _glowAnimation.value),
                    blurRadius: 20 * _glowAnimation.value,
                    spreadRadius: 2 * _glowAnimation.value,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    onLongPress: widget.onLongPress,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.darkSurfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _isHovered ? AppColors.primary.withValues(alpha: 0.5) : AppColors.darkBorder, width: _isHovered ? 1.5 : 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Channel logo section
                          Expanded(
                            flex: 3,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildLogo(),
                                // Gradient overlay for depth
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, AppColors.darkSurfaceVariant.withValues(alpha: 0.8)], stops: const [0.5, 1.0]),
                                    ),
                                  ),
                                ),
                                // Favorite indicator
                                if (widget.channel.isFavorite)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.2), shape: BoxShape.circle),
                                      child: Icon(Icons.favorite_rounded, color: AppColors.accent, size: 16),
                                    ),
                                  ),
                                // Live indicator if live
                                Positioned(top: 8, left: 8, child: _LiveIndicator()),
                              ],
                            ),
                          ),
                          // Channel info section
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    widget.channel.displayName,
                                    style: TextStyle(color: AppColors.darkOnSurface, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.channel.group != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.channel.group!,
                                      style: TextStyle(color: AppColors.darkOnSurfaceVariant, fontSize: 11),
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
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogo() {
    if (widget.channel.logoUrl != null && widget.channel.logoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.channel.logoUrl!,
        fit: BoxFit.contain,
        // Add memory limits for better performance on Android
        memCacheWidth: 200,
        memCacheHeight: 200,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.darkSurface,
      child: Center(child: Icon(Icons.tv_rounded, size: 36, color: AppColors.darkOnSurfaceMuted)),
    );
  }
}

/// Animated live indicator
class _LiveIndicator extends StatefulWidget {
  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this)..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.live.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [BoxShadow(color: AppColors.live.withValues(alpha: 0.4 * _pulseAnimation.value), blurRadius: 8, spreadRadius: 1)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.5 * _pulseAnimation.value), blurRadius: 4)],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'LIVE',
                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Premium list tile variant for channels
class ChannelListTile extends StatefulWidget {
  final Channel channel;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onLongPress;

  const ChannelListTile({super.key, required this.channel, required this.onTap, this.onFavorite, this.onLongPress});

  @override
  State<ChannelListTile> createState() => _ChannelListTileState();
}

class _ChannelListTileState extends State<ChannelListTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: _isHovered ? AppColors.darkSurfaceHover : AppColors.darkSurfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _isHovered ? AppColors.primary.withValues(alpha: 0.3) : AppColors.darkBorder),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(8)),
                      child: _buildLogo(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Channel info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.channel.displayName,
                                style: TextStyle(color: AppColors.darkOnSurface, fontSize: 15, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.channel.isFavorite) ...[const SizedBox(width: 8), Icon(Icons.favorite_rounded, color: AppColors.accent, size: 16)],
                          ],
                        ),
                        if (widget.channel.group != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.channel.group!,
                            style: TextStyle(color: AppColors.darkOnSurfaceVariant, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        // Current program (if available)
                        _ChannelCurrentProgram(channel: widget.channel),
                      ],
                    ),
                  ),
                  // Actions
                  if (widget.onFavorite != null)
                    IconButton(
                      icon: Icon(widget.channel.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: widget.channel.isFavorite ? AppColors.accent : AppColors.darkOnSurfaceMuted),
                      onPressed: widget.onFavorite,
                    ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.darkOnSurfaceMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    if (widget.channel.logoUrl != null && widget.channel.logoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.channel.logoUrl!,
        fit: BoxFit.contain,
        // Add memory limits for better performance on Android
        memCacheWidth: 200,
        memCacheHeight: 200,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Center(child: Icon(Icons.tv_rounded, size: 24, color: AppColors.darkOnSurfaceMuted));
  }
}

/// Shows current program for a channel if EPG data is available
class _ChannelCurrentProgram extends ConsumerWidget {
  final Channel channel;

  const _ChannelCurrentProgram({required this.channel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programAsync = ref.watch(currentProgramProvider((playlistId: channel.playlistId, channelId: channel.epgId)));

    return programAsync.when(
      data: (program) {
        if (program == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  program.title,
                  style: TextStyle(color: AppColors.primary, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
