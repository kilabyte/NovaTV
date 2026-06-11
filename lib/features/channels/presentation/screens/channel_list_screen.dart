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
import '../../../../shared/widgets/tv_focusable.dart';

/// Clean channel list with inline EPG info
class ChannelListScreen extends ConsumerWidget {
  const ChannelListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(filteredChannelsProvider);
    final selectedGroup = ref.watch(selectedGroupProvider);
    final playlistsAsync = ref.watch(playlistNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header with search and filter
          _ChannelHeader(
            selectedGroup: selectedGroup,
            onGroupCleared: () {
              ref.read(selectedGroupProvider.notifier).state = null;
            },
          ),

          // Channel list
          Expanded(
            child: channelsAsync.when(
              data: (channels) {
                if (channels.isEmpty) {
                  return _EmptyState(hasPlaylist: playlistsAsync.valueOrNull?.isNotEmpty ?? false);
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: channels.length,
                  itemBuilder: (context, index) {
                    // Wrap in RepaintBoundary to isolate repaints and improve scrolling performance
                    return RepaintBoundary(
                      child: _ChannelRow(channel: channels[index]),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (error, _) => _ErrorState(error: error.toString()),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════════════════════

class _ChannelHeader extends StatelessWidget {
  final String? selectedGroup;
  final VoidCallback onGroupCleared;

  const _ChannelHeader({required this.selectedGroup, required this.onGroupCleared});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Title
          Text(
            selectedGroup ?? 'All Channels',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
          ),

          // Clear filter button if group selected
          if (selectedGroup != null) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onGroupCleared,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(4)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.close, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 4),
                    Text('Clear', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],

          const Spacer(),

          // Search button
          IconButton(icon: const Icon(Icons.search_rounded), color: AppColors.textSecondary, onPressed: () => context.push(Routes.search)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CHANNEL ROW WITH INLINE EPG
// ═══════════════════════════════════════════════════════════════════════════

class _ChannelRow extends ConsumerStatefulWidget {
  final Channel channel;

  const _ChannelRow({required this.channel});

  @override
  ConsumerState<_ChannelRow> createState() => _ChannelRowState();
}

class _ChannelRowState extends ConsumerState<_ChannelRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Use the batched current-programs provider so every row in a long list
    // shares a single Hive fetch per playlist/minute instead of each one
    // hitting the repo. Keyed by the channel's OWN playlist: this list spans
    // all playlists, so using the first playlist's id left every other
    // playlist's rows without program info.
    final epgId = widget.channel.epgId.toLowerCase();
    final programAsync = ref.watch(currentProgramsProvider(widget.channel.playlistId))
        .whenData((map) => map[epgId]);

    final isFavorite = ref.watch(isFavoriteProvider(widget.channel.id)).valueOrNull ?? false;

    return TvFocusable(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push(Routes.playerPath(widget.channel.id));
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: _isHovered ? AppColors.surfaceHover : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              // Channel logo
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(8)),
                clipBehavior: Clip.antiAlias,
                child: widget.channel.logoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: widget.channel.logoUrl!,
                        fit: BoxFit.contain,
                        // Add memory limits for better performance on Android
                        memCacheWidth: 48,
                        memCacheHeight: 48,
                        errorWidget: (_, __, ___) => _LogoPlaceholder(),
                      )
                    : _LogoPlaceholder(),
              ),

              const SizedBox(width: 12),

              // Channel info with EPG
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Channel name row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.channel.displayName,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isFavorite)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.star_rounded, size: 14, color: AppColors.favorite),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Current program info
                    programAsync.when(
                      data: (program) => _ProgramInfo(program: program),
                      loading: () => const Text('Loading...', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      error: (_, __) => Text(widget.channel.group ?? 'No program info', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Progress bar (for current program)
              SizedBox(
                width: 80,
                child: programAsync.when(
                  data: (program) => program != null ? _ProgressBar(progress: program.progress) : const SizedBox(),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ),

              const SizedBox(width: 12),

              // Time remaining
              SizedBox(
                width: 50,
                child: programAsync.when(
                  data: (program) => program != null
                      ? Text(
                          _formatTimeRemaining(program.end),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          textAlign: TextAlign.right,
                        )
                      : const SizedBox(),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ),

              // Favorite button on hover
              if (_isHovered) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    // Call the notifier directly (matching every other call
                    // site): the old toggleFavoriteProvider was a cached
                    // Provider.family whose side effect ran once per channel
                    // per session, so the star silently stopped working after
                    // the first tap.
                    ref.read(favoriteNotifierProvider.notifier).toggleFavorite(widget.channel.id);
                  },
                  child: Icon(isFavorite ? Icons.star_rounded : Icons.star_outline_rounded, size: 20, color: isFavorite ? AppColors.favorite : AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeRemaining(DateTime endTime) {
    final remaining = endTime.difference(DateTime.now());
    if (remaining.isNegative) return '';
    if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes % 60}m';
    }
    return '${remaining.inMinutes}m';
  }
}

class _ProgramInfo extends StatelessWidget {
  final Program? program;

  const _ProgramInfo({required this.program});

  @override
  Widget build(BuildContext context) {
    if (program == null) {
      return const Text('No program info', style: TextStyle(color: AppColors.textMuted, fontSize: 13));
    }

    return Text(
      program!.title,
      style: const TextStyle(color: AppColors.primary, fontSize: 13),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;

  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(2)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
        ),
      ),
    );
  }
}

class _LogoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Icon(Icons.tv_rounded, size: 20, color: AppColors.textMuted));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMPTY & ERROR STATES
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final bool hasPlaylist;

  const _EmptyState({required this.hasPlaylist});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(hasPlaylist ? Icons.live_tv_rounded : Icons.playlist_add_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              hasPlaylist ? 'No channels found' : 'Add a playlist to get started',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (!hasPlaylist) ...[
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.go('${Routes.playlists}/add'),
                child: const Text('Add Playlist', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;

  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            const Text(
              'Failed to load channels',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
