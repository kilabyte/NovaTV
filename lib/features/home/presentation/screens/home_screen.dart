import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../shared/widgets/glass_components.dart';
import '../../../epg/domain/entities/program.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../playlist/domain/entities/channel.dart';
import '../../../playlist/presentation/providers/playlist_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';

/// Liquid Glass Home Screen - macOS Tahoe / iOS 26 design
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistNotifierProvider);
    final favoritesAsync = ref.watch(favoriteChannelsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: playlistsAsync.when(
        data: (playlists) {
          if (playlists.isEmpty) {
            return _WelcomeScreen();
          }
          return CustomScrollView(
            slivers: [
              // Glass Header
              _HomeHeader(),

              // Continue Watching Section
              SliverToBoxAdapter(child: _ContinueWatchingSection()),

              // Quick Actions Row
              SliverToBoxAdapter(child: _QuickActionsRow()),

              // Favorites Grid
              SliverToBoxAdapter(
                child: favoritesAsync.when(
                  data: (favorites) => _FavoritesGrid(favorites: favorites),
                  loading: () => const SizedBox(height: 100),
                  error: (_, __) => const SizedBox(),
                ),
              ),

              // What's On Now
              SliverToBoxAdapter(child: _WhatsOnNowSection()),

              // Bottom Padding for navigation bar
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
        loading: () => Center(
          child: GlowContainer(
            glowColor: AppColors.primary,
            glowRadius: 40,
            child: const CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (error, _) => _ErrorScreen(error: error.toString()),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HOME HEADER - Glass floating style
// ═══════════════════════════════════════════════════════════════════════════
class _HomeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 72,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.4), Colors.transparent]),
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          // Gradient title
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(colors: [AppColors.primary, AppColors.auroraPurple]).createShader(bounds),
            child: const Text(
              'Home',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
            ),
          ),
        ],
      ),
      actions: [
        GlassIconButton(icon: Icons.search_rounded, onPressed: () => context.push(Routes.search)),
        const SizedBox(width: 12),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CONTINUE WATCHING SECTION - Glass card
// ═══════════════════════════════════════════════════════════════════════════
class _ContinueWatchingSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final lastChannelId = settings.lastPlayedChannelId;

    if (!settings.rememberLastChannel || lastChannelId == null) {
      return const SizedBox();
    }

    final channelsAsync = ref.watch(allChannelsProvider);

    return channelsAsync.when(
      data: (channels) {
        final lastChannel = channels.where((c) => c.id == lastChannelId).firstOrNull;
        if (lastChannel == null) return const SizedBox();
        return _ContinueWatchingCard(channel: lastChannel);
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}

class _ContinueWatchingCard extends StatefulWidget {
  final Channel channel;

  const _ContinueWatchingCard({required this.channel});

  @override
  State<_ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<_ContinueWatchingCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            context.push(Routes.playerPath(widget.channel.id));
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(boxShadow: _isHovered ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: -5)] : null),
            child: GlassCard(
              blur: 25,
              opacity: 0.12,
              borderRadius: 16,
              tintColor: _isHovered ? AppColors.primary : null,
              child: SizedBox(
                height: 100,
                child: Row(
                  children: [
                    // Channel Logo with glow
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.glassBackgroundMedium,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                      ),
                      child: widget.channel.logoUrl != null
                          ? ClipRRect(
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                              child: CachedNetworkImage(
                                imageUrl: widget.channel.logoUrl!,
                                fit: BoxFit.contain,
                                // Add memory limits for better performance on Android
                                memCacheWidth: 100,
                                memCacheHeight: 100,
                                errorWidget: (_, __, ___) => _buildPlaceholder(),
                              ),
                            )
                          : _buildPlaceholder(),
                    ),
                    // Info
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Glowing label
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                'CONTINUE WATCHING',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.channel.displayName,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.darkOnSurface),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.channel.group != null) ...[const SizedBox(height: 2), Text(widget.channel.group!, style: TextStyle(fontSize: 13, color: AppColors.darkOnSurfaceVariant))],
                          ],
                        ),
                      ),
                    ),
                    // Play Button with glow
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: GlowContainer(
                        glowColor: AppColors.primary,
                        glowRadius: _isHovered ? 25 : 15,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(24)),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
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
  }

  Widget _buildPlaceholder() {
    return Center(child: Icon(Icons.tv_rounded, size: 32, color: AppColors.darkOnSurfaceMuted));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// QUICK ACTIONS ROW - Glass buttons with color accent glow
// ═══════════════════════════════════════════════════════════════════════════
class _QuickActionsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _GlassQuickActionButton(icon: Icons.live_tv_rounded, label: 'Live TV', color: AppColors.primary, onTap: () => context.go(Routes.channels)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _GlassQuickActionButton(icon: Icons.calendar_month_rounded, label: 'Guide', color: AppColors.auroraPurple, onTap: () => context.go(Routes.tvGuide)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _GlassQuickActionButton(icon: Icons.playlist_play_rounded, label: 'Playlists', color: AppColors.secondary, onTap: () => context.go(Routes.playlists)),
          ),
        ],
      ),
    );
  }
}

class _GlassQuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GlassQuickActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  State<_GlassQuickActionButton> createState() => _GlassQuickActionButtonState();
}

class _GlassQuickActionButtonState extends State<_GlassQuickActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(boxShadow: _isHovered ? [BoxShadow(color: widget.color.withValues(alpha: 0.4), blurRadius: 25, spreadRadius: -5)] : null),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _isHovered ? [widget.color.withValues(alpha: 0.25), widget.color.withValues(alpha: 0.12)] : [Colors.white.withValues(alpha: 0.12), Colors.white.withValues(alpha: 0.06)]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _isHovered ? widget.color.withValues(alpha: 0.5) : AppColors.glassBorder, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: widget.color, size: 30),
                    const SizedBox(height: 10),
                    Text(
                      widget.label,
                      style: TextStyle(color: _isHovered ? widget.color : AppColors.darkOnSurface, fontSize: 13, fontWeight: FontWeight.w600),
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
// FAVORITES GRID - Glass channel cards
// ═══════════════════════════════════════════════════════════════════════════
class _FavoritesGrid extends StatelessWidget {
  final List<Channel> favorites;

  const _FavoritesGrid({required this.favorites});

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GlowContainer(
                    glowColor: AppColors.favorite,
                    glowRadius: 10,
                    child: Icon(Icons.star_rounded, color: AppColors.favorite, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Favorites',
                    style: TextStyle(color: AppColors.darkOnSurface, fontSize: 19, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => context.go(Routes.favorites),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    'See All',
                    style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: favorites.length > 10 ? 10 : favorites.length,
            itemBuilder: (context, index) {
              return _GlassFavoriteCard(channel: favorites[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _GlassFavoriteCard extends StatefulWidget {
  final Channel channel;

  const _GlassFavoriteCard({required this.channel});

  @override
  State<_GlassFavoriteCard> createState() => _GlassFavoriteCardState();
}

class _GlassFavoriteCardState extends State<_GlassFavoriteCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push(Routes.playerPath(widget.channel.id));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 105,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(boxShadow: _isHovered ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: -5)] : null),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _isHovered ? [AppColors.primary.withValues(alpha: 0.2), AppColors.primary.withValues(alpha: 0.08)] : [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _isHovered ? AppColors.primary.withValues(alpha: 0.4) : AppColors.glassBorder, width: 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo with subtle glow
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppColors.glassBackgroundMedium,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _isHovered ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 10)] : null,
                      ),
                      child: widget.channel.logoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: widget.channel.logoUrl!,
                                fit: BoxFit.contain,
                                errorWidget: (_, __, ___) => Icon(Icons.tv_rounded, size: 26, color: AppColors.darkOnSurfaceMuted),
                              ),
                            )
                          : Icon(Icons.tv_rounded, size: 26, color: AppColors.darkOnSurfaceMuted),
                    ),
                    const SizedBox(height: 10),
                    // Name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        widget.channel.displayName,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _isHovered ? AppColors.primary : AppColors.darkOnSurface),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
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
// WHAT'S ON NOW SECTION - Glass list items
// ═══════════════════════════════════════════════════════════════════════════
class _WhatsOnNowSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteChannelsProvider);
    final playlistsAsync = ref.watch(playlistNotifierProvider);

    return favoritesAsync.when(
      data: (favorites) {
        if (favorites.isEmpty) return const SizedBox();

        final playlistId = playlistsAsync.valueOrNull?.firstOrNull?.id ?? '';
        if (playlistId.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.live,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppColors.live.withValues(alpha: 0.6), blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "What's On Now",
                        style: TextStyle(color: AppColors.darkOnSurface, fontSize: 19, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => context.go(Routes.tvGuide),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        'Full Guide',
                        style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: favorites.length > 5 ? 5 : favorites.length,
              itemBuilder: (context, index) {
                return _GlassNowPlayingItem(playlistId: playlistId, channel: favorites[index]);
              },
            ),
          ],
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}

class _GlassNowPlayingItem extends ConsumerStatefulWidget {
  final String playlistId;
  final Channel channel;

  const _GlassNowPlayingItem({required this.playlistId, required this.channel});

  @override
  ConsumerState<_GlassNowPlayingItem> createState() => _GlassNowPlayingItemState();
}

class _GlassNowPlayingItemState extends ConsumerState<_GlassNowPlayingItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final programAsync = ref.watch(currentProgramProvider((playlistId: widget.playlistId, channelId: widget.channel.tvgId ?? widget.channel.id)));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push(Routes.playerPath(widget.channel.id));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(boxShadow: _isHovered ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: -5)] : null),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _isHovered ? [AppColors.primary.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.06)] : [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.04)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _isHovered ? AppColors.primary.withValues(alpha: 0.3) : AppColors.glassBorder, width: 1),
                ),
                child: Row(
                  children: [
                    // Channel Logo
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: AppColors.glassBackgroundMedium, borderRadius: BorderRadius.circular(10)),
                      child: widget.channel.logoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                imageUrl: widget.channel.logoUrl!,
                                fit: BoxFit.contain,
                                errorWidget: (_, __, ___) => Icon(Icons.tv_rounded, size: 22, color: AppColors.darkOnSurfaceMuted),
                              ),
                            )
                          : Icon(Icons.tv_rounded, size: 22, color: AppColors.darkOnSurfaceMuted),
                    ),
                    const SizedBox(width: 14),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.channel.displayName,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.darkOnSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          programAsync.when(
                            data: (program) => _buildProgramInfo(program),
                            loading: () => Text('Loading...', style: TextStyle(fontSize: 12, color: AppColors.darkOnSurfaceMuted)),
                            error: (_, __) => Text('No program info', style: TextStyle(fontSize: 12, color: AppColors.darkOnSurfaceMuted)),
                          ),
                        ],
                      ),
                    ),
                    // Play indicator with glow
                    GlowContainer(
                      glowColor: AppColors.primary,
                      glowRadius: _isHovered ? 15 : 8,
                      child: Icon(Icons.play_circle_filled_rounded, color: AppColors.primary, size: 36),
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

  Widget _buildProgramInfo(Program? program) {
    if (program == null) {
      return Text('No program info', style: TextStyle(fontSize: 12, color: AppColors.darkOnSurfaceMuted));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          program.title,
          style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        // Glass progress bar
        Stack(
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(color: AppColors.glassBackgroundMedium, borderRadius: BorderRadius.circular(2)),
            ),
            FractionallySizedBox(
              widthFactor: program.progress,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WELCOME SCREEN - Glass panel design
// ═══════════════════════════════════════════════════════════════════════════
class _WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassCard(
          blur: 30,
          opacity: 0.1,
          borderRadius: 24,
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo with aurora gradient and glow
              GlowContainer(
                glowColor: AppColors.primary,
                glowRadius: 40,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(24)),
                  child: const Icon(Icons.live_tv_rounded, color: Colors.white, size: 48),
                ),
              ),
              const SizedBox(height: 32),
              // Gradient text
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(colors: [AppColors.primary, AppColors.auroraPurple]).createShader(bounds),
                child: const Text(
                  'Welcome to NovaIPTV',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Stream your favorite channels anywhere',
                style: TextStyle(fontSize: 16, color: AppColors.darkOnSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Glass button
              GlassButton(
                onPressed: () => context.push('${Routes.playlists}/add'),
                accentColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                borderRadius: 14,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      'Add Your First Playlist',
                      style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Add an M3U/M3U8 playlist URL to start streaming', style: TextStyle(fontSize: 13, color: AppColors.darkOnSurfaceMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ERROR SCREEN - Glass error display
// ═══════════════════════════════════════════════════════════════════════════
class _ErrorScreen extends StatelessWidget {
  final String error;

  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassCard(
          blur: 25,
          opacity: 0.1,
          borderRadius: 20,
          padding: const EdgeInsets.all(32),
          tintColor: AppColors.error,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlowContainer(
                glowColor: AppColors.error,
                glowRadius: 20,
                child: Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
              ),
              const SizedBox(height: 20),
              Text(
                'Something went wrong',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.darkOnSurface),
              ),
              const SizedBox(height: 10),
              Text(
                error,
                style: TextStyle(color: AppColors.darkOnSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
