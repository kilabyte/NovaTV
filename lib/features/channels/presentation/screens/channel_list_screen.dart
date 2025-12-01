import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../playlist/domain/entities/channel.dart';
import '../../../playlist/presentation/providers/playlist_providers.dart';

/// TiViMate-style channel list with two-panel layout
class ChannelListScreen extends ConsumerStatefulWidget {
  const ChannelListScreen({super.key});

  @override
  ConsumerState<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends ConsumerState<ChannelListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: ResponsiveLayout(
        mobile: _MobileChannelList(),
        tablet: _DesktopChannelList(),
        desktop: _DesktopChannelList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DESKTOP/TABLET - TWO PANEL LAYOUT
// ═══════════════════════════════════════════════════════════════════════════
class _DesktopChannelList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(filteredChannelsProvider);
    final groupsAsync = ref.watch(channelGroupsProvider);
    final selectedGroup = ref.watch(selectedGroupProvider);

    return Row(
      children: [
        // Left Panel - Groups
        Container(
          width: 240,
          decoration: BoxDecoration(
            color: AppColors.darkSidebar,
            border: Border(
              right: BorderSide(color: AppColors.darkBorder, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Text(
                  'Live TV',
                  style: TextStyle(
                    color: AppColors.darkOnSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              // Groups Label
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'GROUPS',
                      style: TextStyle(
                        color: AppColors.darkOnSurfaceMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    groupsAsync.when(
                      data: (groups) => Text(
                        '${groups.length}',
                        style: TextStyle(
                          color: AppColors.darkOnSurfaceMuted,
                          fontSize: 11,
                        ),
                      ),
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                    ),
                  ],
                ),
              ),
              // Groups List
              Expanded(
                child: groupsAsync.when(
                  data: (groups) => _GroupsList(
                    groups: groups,
                    selectedGroup: selectedGroup,
                    onGroupSelected: (group) {
                      ref.read(selectedGroupProvider.notifier).state = group;
                    },
                  ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (_, __) => const SizedBox(),
                ),
              ),
            ],
          ),
        ),
        // Right Panel - Channels
        Expanded(
          child: Column(
            children: [
              // Channel Header
              _ChannelHeader(
                selectedGroup: selectedGroup,
                channelCount: channelsAsync.valueOrNull?.length ?? 0,
              ),
              // Channels Grid
              Expanded(
                child: channelsAsync.when(
                  data: (channels) {
                    if (channels.isEmpty) return _EmptyState();
                    return _ChannelGrid(channels: channels);
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (error, _) => _ErrorState(error: error.toString()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MOBILE - COMPACT LAYOUT
// ═══════════════════════════════════════════════════════════════════════════
class _MobileChannelList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(filteredChannelsProvider);
    final groupsAsync = ref.watch(channelGroupsProvider);
    final selectedGroup = ref.watch(selectedGroupProvider);

    return Column(
      children: [
        // Header
        SafeArea(
          bottom: false,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Live TV',
                  style: TextStyle(
                    color: AppColors.darkOnSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.search_rounded, color: AppColors.darkOnSurfaceVariant),
                  onPressed: () => context.push(Routes.search),
                ),
              ],
            ),
          ),
        ),
        // Group Filter Bar
        groupsAsync.when(
          data: (groups) {
            if (groups.isEmpty) return const SizedBox();
            return _MobileGroupBar(
              groups: groups,
              selectedGroup: selectedGroup,
              onGroupSelected: (group) {
                ref.read(selectedGroupProvider.notifier).state = group;
              },
            );
          },
          loading: () => const SizedBox(height: 48),
          error: (_, __) => const SizedBox(),
        ),
        // Channels List
        Expanded(
          child: channelsAsync.when(
            data: (channels) {
              if (channels.isEmpty) return _EmptyState();
              return _MobileChannelGrid(channels: channels);
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (error, _) => _ErrorState(error: error.toString()),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GROUPS LIST - Desktop side panel
// ═══════════════════════════════════════════════════════════════════════════
class _GroupsList extends StatelessWidget {
  final List<String> groups;
  final String? selectedGroup;
  final ValueChanged<String?> onGroupSelected;

  const _GroupsList({
    required this.groups,
    required this.selectedGroup,
    required this.onGroupSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: groups.length + 1, // +1 for "All"
      itemBuilder: (context, index) {
        if (index == 0) {
          return _GroupItem(
            name: 'All Channels',
            icon: Icons.live_tv_rounded,
            color: AppColors.primary,
            isSelected: selectedGroup == null,
            onTap: () => onGroupSelected(null),
          );
        }
        final group = groups[index - 1];
        final colorIndex = (index - 1) % AppColors.groupColors.length;
        return _GroupItem(
          name: group,
          color: AppColors.groupColors[colorIndex],
          isSelected: selectedGroup == group,
          onTap: () => onGroupSelected(group),
        );
      },
    );
  }
}

class _GroupItem extends StatefulWidget {
  final String name;
  final IconData? icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _GroupItem({
    required this.name,
    this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_GroupItem> createState() => _GroupItemState();
}

class _GroupItemState extends State<_GroupItem> {
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
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.sidebarSelectedBg
                : _isHovered
                    ? AppColors.sidebarHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: widget.isSelected
                ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            children: [
              // Color indicator
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? AppColors.primary
                      : widget.color.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // Icon
              Icon(
                widget.icon ?? Icons.folder_rounded,
                color: widget.isSelected
                    ? AppColors.primary
                    : AppColors.darkOnSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 10),
              // Name
              Expanded(
                child: Text(
                  widget.name,
                  style: TextStyle(
                    color: widget.isSelected
                        ? AppColors.darkOnSurface
                        : AppColors.darkOnSurfaceVariant,
                    fontSize: 14,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                  maxLines: 1,
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
// MOBILE GROUP BAR
// ═══════════════════════════════════════════════════════════════════════════
class _MobileGroupBar extends StatelessWidget {
  final List<String> groups;
  final String? selectedGroup;
  final ValueChanged<String?> onGroupSelected;

  const _MobileGroupBar({
    required this.groups,
    required this.selectedGroup,
    required this.onGroupSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: groups.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _MobileGroupChip(
              label: 'All',
              isSelected: selectedGroup == null,
              onTap: () => onGroupSelected(null),
            );
          }
          final group = groups[index - 1];
          return _MobileGroupChip(
            label: group,
            isSelected: selectedGroup == group,
            onTap: () => onGroupSelected(group),
          );
        },
      ),
    );
  }
}

class _MobileGroupChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MobileGroupChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.darkSurfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.darkBackground : AppColors.darkOnSurface,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CHANNEL HEADER
// ═══════════════════════════════════════════════════════════════════════════
class _ChannelHeader extends StatelessWidget {
  final String? selectedGroup;
  final int channelCount;

  const _ChannelHeader({
    required this.selectedGroup,
    required this.channelCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.darkBackground,
        border: Border(
          bottom: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            selectedGroup ?? 'All Channels',
            style: TextStyle(
              color: AppColors.darkOnSurface,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$channelCount channels',
              style: TextStyle(
                color: AppColors.darkOnSurfaceMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.search_rounded, color: AppColors.darkOnSurfaceVariant),
            onPressed: () => context.push(Routes.search),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CHANNEL GRID - Desktop
// ═══════════════════════════════════════════════════════════════════════════
class _ChannelGrid extends ConsumerWidget {
  final List<Channel> channels;

  const _ChannelGrid({required this.channels});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        return _ChannelCard(
          channel: channels[index],
          onTap: () => context.push(Routes.playerPath(channels[index].id)),
          onFavorite: () {
            ref.read(favoriteNotifierProvider.notifier).toggleFavorite(channels[index].id);
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MOBILE CHANNEL GRID
// ═══════════════════════════════════════════════════════════════════════════
class _MobileChannelGrid extends ConsumerWidget {
  final List<Channel> channels;

  const _MobileChannelGrid({required this.channels});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        return _ChannelCard(
          channel: channels[index],
          compact: true,
          onTap: () => context.push(Routes.playerPath(channels[index].id)),
          onFavorite: () {
            ref.read(favoriteNotifierProvider.notifier).toggleFavorite(channels[index].id);
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CHANNEL CARD
// ═══════════════════════════════════════════════════════════════════════════
class _ChannelCard extends StatefulWidget {
  final Channel channel;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const _ChannelCard({
    required this.channel,
    this.compact = false,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
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
        onLongPress: widget.onFavorite,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
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
              Expanded(
                flex: 3,
                child: Container(
                  margin: EdgeInsets.all(widget.compact ? 8 : 12),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: widget.channel.logoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: widget.channel.logoUrl!,
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) => Icon(
                                Icons.tv_rounded,
                                size: widget.compact ? 24 : 32,
                                color: AppColors.darkOnSurfaceMuted,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.tv_rounded,
                            size: widget.compact ? 24 : 32,
                            color: AppColors.darkOnSurfaceMuted,
                          ),
                  ),
                ),
              ),
              // Name
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.compact ? 6 : 10,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.channel.displayName,
                        style: TextStyle(
                          fontSize: widget.compact ? 10 : 12,
                          fontWeight: FontWeight.w500,
                          color: _isHovered
                              ? AppColors.primary
                              : AppColors.darkOnSurface,
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.channel.isFavorite) ...[
                        const SizedBox(height: 4),
                        Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.favorite,
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMPTY & ERROR STATES
// ═══════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.tv_off_rounded,
            size: 64,
            color: AppColors.darkOnSurfaceMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'No channels found',
            style: TextStyle(
              color: AppColors.darkOnSurface,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a playlist to start watching',
            style: TextStyle(
              color: AppColors.darkOnSurfaceMuted,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go(Routes.playlists),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Playlist'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
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
            'Error loading channels',
            style: TextStyle(
              color: AppColors.darkOnSurface,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              color: AppColors.darkOnSurfaceMuted,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
