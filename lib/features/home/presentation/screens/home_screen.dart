import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../epg/domain/entities/program.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../playlist/domain/entities/channel.dart';
import '../../../playlist/presentation/providers/playlist_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';

/// TiViMate-style Home Screen - Clean, content-first design
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
              // Clean Header
              _HomeHeader(),

              // Continue Watching Section
              SliverToBoxAdapter(
                child: _ContinueWatchingSection(),
              ),

              // Quick Actions Row
              SliverToBoxAdapter(
                child: _QuickActionsRow(),
              ),

              // Favorites Grid
              SliverToBoxAdapter(
                child: favoritesAsync.when(
                  data: (favorites) => _FavoritesGrid(favorites: favorites),
                  loading: () => const SizedBox(height: 100),
                  error: (_, __) => const SizedBox(),
                ),
              ),

              // What's On Now
              SliverToBoxAdapter(
                child: _WhatsOnNowSection(),
              ),

              // Bottom Padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
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
// HOME HEADER - Clean, minimal
// ═══════════════════════════════════════════════════════════════════════════
class _HomeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      backgroundColor: AppColors.darkBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 60,
      title: Row(
        children: [
          Text(
            'Home',
            style: TextStyle(
              color: AppColors.darkOnSurface,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search_rounded, color: AppColors.darkOnSurfaceVariant),
          onPressed: () => context.push(Routes.search),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CONTINUE WATCHING SECTION
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

class _ContinueWatchingCard extends StatelessWidget {
  final Channel channel;

  const _ContinueWatchingCard({required this.channel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push(Routes.playerPath(channel.id));
        },
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Channel Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                ),
                child: channel.logoUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                        child: CachedNetworkImage(
                          imageUrl: channel.logoUrl!,
                          fit: BoxFit.contain,
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
                      Text(
                        'CONTINUE WATCHING',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        channel.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkOnSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (channel.group != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          channel.group!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.darkOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Play Button
              Container(
                margin: const EdgeInsets.only(right: 16),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
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
        size: 32,
        color: AppColors.darkOnSurfaceMuted,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// QUICK ACTIONS ROW - TiViMate style
// ═══════════════════════════════════════════════════════════════════════════
class _QuickActionsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionButton(
              icon: Icons.live_tv_rounded,
              label: 'Live TV',
              color: AppColors.primary,
              onTap: () => context.go(Routes.channels),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.calendar_month_rounded,
              label: 'Guide',
              color: AppColors.accentPurple,
              onTap: () => context.go(Routes.tvGuide),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.playlist_play_rounded,
              label: 'Playlists',
              color: AppColors.secondary,
              onTap: () => context.go(Routes.playlists),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.color.withValues(alpha: 0.15)
                : AppColors.darkSurfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.4)
                  : AppColors.darkBorder,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: widget.color,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: _isHovered ? widget.color : AppColors.darkOnSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
// FAVORITES GRID - TiViMate style channel grid
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
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: AppColors.favorite,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Favorites',
                    style: TextStyle(
                      color: AppColors.darkOnSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => context.go(Routes.favorites),
                child: Text(
                  'See All',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: favorites.length > 10 ? 10 : favorites.length,
            itemBuilder: (context, index) {
              return _FavoriteChannelCard(channel: favorites[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _FavoriteChannelCard extends StatefulWidget {
  final Channel channel;

  const _FavoriteChannelCard({required this.channel});

  @override
  State<_FavoriteChannelCard> createState() => _FavoriteChannelCardState();
}

class _FavoriteChannelCardState extends State<_FavoriteChannelCard> {
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
          duration: const Duration(milliseconds: 150),
          width: 100,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.darkSurfaceHover
                : AppColors.darkSurfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.darkBorder,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: widget.channel.logoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: widget.channel.logoUrl!,
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
              const SizedBox(height: 8),
              // Name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  widget.channel.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _isHovered
                        ? AppColors.primary
                        : AppColors.darkOnSurface,
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "What's On Now",
                    style: TextStyle(
                      color: AppColors.darkOnSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go(Routes.tvGuide),
                    child: Text(
                      'Full Guide',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
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
                return _NowPlayingItem(
                  playlistId: playlistId,
                  channel: favorites[index],
                );
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

class _NowPlayingItem extends ConsumerWidget {
  final String playlistId;
  final Channel channel;

  const _NowPlayingItem({
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

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push(Routes.playerPath(channel.id));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Channel Logo
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: channel.logoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: channel.logoUrl!,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => Icon(
                          Icons.tv_rounded,
                          size: 20,
                          color: AppColors.darkOnSurfaceMuted,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.tv_rounded,
                      size: 20,
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
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.darkOnSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
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
            // Play indicator
            Icon(
              Icons.play_circle_filled_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ],
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
// WELCOME SCREEN
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.live_tv_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to NovaTV',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.darkOnSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Stream your favorite channels anywhere',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.darkOnSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            FilledButton.icon(
              onPressed: () => context.push('${Routes.playlists}/add'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Your First Playlist'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.darkOnSurface,
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
