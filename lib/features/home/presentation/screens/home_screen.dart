import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../shared/widgets/premium_widgets.dart';
import '../../../epg/domain/entities/program.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../playlist/domain/entities/channel.dart';
import '../../../playlist/presentation/providers/playlist_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';

/// Premium Home Screen with cinematic design
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistNotifierProvider);
    final favoritesAsync = ref.watch(favoriteChannelsProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: playlistsAsync.when(
        data: (playlists) {
          if (playlists.isEmpty) {
            return _WelcomeScreen();
          }
          return CustomScrollView(
            slivers: [
              // Premium App Bar
              _PremiumAppBar(),

              // Hero Section - Continue Watching
              SliverToBoxAdapter(
                child: _HeroSection(),
              ),

              // Quick Access Cards
              SliverToBoxAdapter(
                child: _QuickAccessSection(),
              ),

              // Favorites Section
              SliverToBoxAdapter(
                child: favoritesAsync.when(
                  data: (favorites) => _FavoritesSection(favorites: favorites),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ),

              // What's On Now
              SliverToBoxAdapter(
                child: _WhatsOnNowSection(),
              ),

              // Bottom Padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, _) => _ErrorScreen(error: error.toString()),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM APP BAR
// ═══════════════════════════════════════════════════════════════════════════
class _PremiumAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
      title: Row(
        children: [
          // Logo
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.gradientPrimary,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const GradientText(
            text: 'NovaTV',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => context.push(Routes.search),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.darkSurfaceVariant,
            foregroundColor: AppColors.darkOnSurface,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          onPressed: () => context.push(Routes.settings),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.darkSurfaceVariant,
            foregroundColor: AppColors.darkOnSurface,
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HERO SECTION - CONTINUE WATCHING
// ═══════════════════════════════════════════════════════════════════════════
class _HeroSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final lastChannelId = settings.lastPlayedChannelId;

    if (!settings.rememberLastChannel || lastChannelId == null) {
      return _FeaturedBanner();
    }

    final channelsAsync = ref.watch(allChannelsProvider);

    return channelsAsync.when(
      data: (channels) {
        final lastChannel = channels.where((c) => c.id == lastChannelId).firstOrNull;
        if (lastChannel == null) return _FeaturedBanner();
        return _ContinueWatchingHero(channel: lastChannel);
      },
      loading: () => _FeaturedBanner(),
      error: (_, __) => _FeaturedBanner(),
    );
  }
}

class _FeaturedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: AppColors.gradientAurora,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CustomPaint(
                painter: _GridPatternPainter(),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Welcome to NovaTV',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Stream your favorite channels anywhere',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start Watching'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueWatchingHero extends StatelessWidget {
  final Channel channel;

  const _ContinueWatchingHero({required this.channel});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      margin: const EdgeInsets.all(16),
      child: GlowContainer(
        glowColor: AppColors.primary,
        blurRadius: 30,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                AppColors.darkSurfaceElevated,
                AppColors.darkSurfaceVariant,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Channel Logo
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: channel.logoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: channel.logoUrl!,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => _buildPlaceholder(),
                          ),
                        )
                      : _buildPlaceholder(),
                ),
              ),
              // Info
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue Watching',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        channel.displayName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkOnSurface,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (channel.group != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          channel.group!,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.darkOnSurfaceVariant,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: () => context.push(
                              Routes.playerPath(channel.id),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                            label: const Text('Resume'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.tv_rounded,
        size: 48,
        color: AppColors.darkOnSurfaceMuted,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// QUICK ACCESS SECTION
// ═══════════════════════════════════════════════════════════════════════════
class _QuickAccessSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Quick Access'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _QuickAccessCard(
                  icon: Icons.live_tv_rounded,
                  label: 'All Channels',
                  color: AppColors.primary,
                  onTap: () => context.go(Routes.channels),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAccessCard(
                  icon: Icons.calendar_month_rounded,
                  label: 'TV Guide',
                  color: AppColors.accentPurple,
                  onTap: () => context.go(Routes.tvGuide),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickAccessCard(
                  icon: Icons.favorite_rounded,
                  label: 'Favorites',
                  color: AppColors.accent,
                  onTap: () => context.go(Routes.favorites),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAccessCard(
                  icon: Icons.playlist_play_rounded,
                  label: 'Playlists',
                  color: AppColors.secondary,
                  onTap: () => context.push(Routes.playlists),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAccessCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickAccessCard> createState() => _QuickAccessCardState();
}

class _QuickAccessCardState extends State<_QuickAccessCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.color.withValues(alpha: 0.15)
                : AppColors.darkSurfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.5)
                  : AppColors.darkBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _isHovered ? widget.color : AppColors.darkOnSurface,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: _isHovered ? widget.color : AppColors.darkOnSurfaceMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FAVORITES SECTION
// ═══════════════════════════════════════════════════════════════════════════
class _FavoritesSection extends StatelessWidget {
  final List<Channel> favorites;

  const _FavoritesSection({required this.favorites});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Favorites',
            actionText: favorites.isNotEmpty ? 'See All' : null,
            onActionTap: () => context.go(Routes.favorites),
          ),
          const SizedBox(height: 8),
          if (favorites.isEmpty)
            _EmptyFavorites()
          else
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: favorites.length > 10 ? 10 : favorites.length,
                itemBuilder: (context, index) {
                  final channel = favorites[index];
                  return _FavoriteCard(channel: channel);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.darkBorder,
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 32,
              color: AppColors.darkOnSurfaceMuted,
            ),
            const SizedBox(height: 8),
            Text(
              'No favorites yet',
              style: TextStyle(
                color: AppColors.darkOnSurfaceMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add channels to your favorites for quick access',
              style: TextStyle(
                color: AppColors.darkOnSurfaceMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteCard extends StatefulWidget {
  final Channel channel;

  const _FavoriteCard({required this.channel});

  @override
  State<_FavoriteCard> createState() => _FavoriteCardState();
}

class _FavoriteCardState extends State<_FavoriteCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => context.push(Routes.playerPath(widget.channel.id)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 120,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.darkBorder,
              width: 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              // Logo
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.darkSurface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                  ),
                  child: widget.channel.logoUrl != null
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(15),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: widget.channel.logoUrl!,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => Icon(
                              Icons.tv_rounded,
                              size: 32,
                              color: AppColors.darkOnSurfaceMuted,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.tv_rounded,
                          size: 32,
                          color: AppColors.darkOnSurfaceMuted,
                        ),
                ),
              ),
              // Name
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.channel.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: _isHovered
                              ? AppColors.primary
                              : AppColors.darkOnSurface,
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WHAT'S ON NOW SECTION
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

        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: "What's On Now",
                actionText: 'Full Guide',
                onActionTap: () => context.go(Routes.tvGuide),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: favorites.length > 5 ? 5 : favorites.length,
                itemBuilder: (context, index) {
                  final channel = favorites[index];
                  return _NowPlayingCard(
                    playlistId: playlistId,
                    channel: channel,
                  );
                },
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}

class _NowPlayingCard extends ConsumerWidget {
  final String playlistId;
  final Channel channel;

  const _NowPlayingCard({
    required this.playlistId,
    required this.channel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programAsync = ref.watch(
      currentProgramProvider((
        playlistId: playlistId,
        channelId: channel.tvgId ?? channel.id,
      )),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.darkSurfaceVariant,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => context.push(Routes.playerPath(channel.id)),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Channel Logo
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: channel.logoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: channel.logoUrl!,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => Icon(
                              Icons.tv_rounded,
                              size: 24,
                              color: AppColors.darkOnSurfaceMuted,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.tv_rounded,
                          size: 24,
                          color: AppColors.darkOnSurfaceMuted,
                        ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      programAsync.when(
                        data: (program) => _buildProgramInfo(program),
                        loading: () => Text(
                          'Loading...',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.darkOnSurfaceMuted,
                          ),
                        ),
                        error: (_, __) => Text(
                          'No program info',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.darkOnSurfaceMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Play Button
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgramInfo(Program? program) {
    if (program == null) {
      return Text(
        'No program info',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.darkOnSurfaceMuted,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          program.title,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: program.progress,
            backgroundColor: AppColors.darkSurface,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
            minHeight: 3,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WELCOME SCREEN (No playlists)
// ═══════════════════════════════════════════════════════════════════════════
class _WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.gradientPrimary,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 56,
              ),
            ),
            const SizedBox(height: 32),
            const GradientText(
              text: 'Welcome to NovaTV',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your premium cross-platform IPTV player',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.darkOnSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: () => context.push('${Routes.playlists}/add'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Your First Playlist'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add an M3U/M3U8 playlist URL to start streaming',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.darkOnSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ERROR SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class _ErrorScreen extends StatelessWidget {
  final String error;

  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: AppColors.darkOnSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CUSTOM PAINTERS
// ═══════════════════════════════════════════════════════════════════════════
class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    const spacing = 30.0;

    for (double i = 0; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(0, i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
