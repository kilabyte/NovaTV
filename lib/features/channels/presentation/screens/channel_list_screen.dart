import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../playlist/domain/entities/channel.dart';
import '../../../playlist/presentation/providers/playlist_providers.dart';
import '../widgets/channel_card.dart';

/// Display mode for channel list
enum ChannelDisplayMode { grid, list }

/// Premium channel list screen with filtering and animations
class ChannelListScreen extends ConsumerStatefulWidget {
  const ChannelListScreen({super.key});

  @override
  ConsumerState<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends ConsumerState<ChannelListScreen> {
  ChannelDisplayMode _displayMode = ChannelDisplayMode.grid;

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(filteredChannelsProvider);
    final groupsAsync = ref.watch(channelGroupsProvider);
    final selectedGroup = ref.watch(selectedGroupProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      extendBodyBehindAppBar: true,
      appBar: _buildPremiumAppBar(context),
      body: Column(
        children: [
          // Space for app bar
          SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),

          // Group filter bar
          groupsAsync.when(
            data: (groups) {
              if (groups.isEmpty) return const SizedBox.shrink();
              return _PremiumGroupFilterBar(
                groups: groups,
                selectedGroup: selectedGroup,
                onGroupSelected: (group) {
                  ref.read(selectedGroupProvider.notifier).state = group;
                },
              );
            },
            loading: () => const SizedBox(height: 56),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Channel list
          Expanded(
            child: channelsAsync.when(
              data: (channels) {
                if (channels.isEmpty) {
                  return _buildEmptyState(context);
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(filteredChannelsProvider);
                    ref.invalidate(channelGroupsProvider);
                  },
                  color: AppColors.primary,
                  backgroundColor: AppColors.darkSurfaceVariant,
                  child: _displayMode == ChannelDisplayMode.grid
                      ? _buildGridView(context, channels)
                      : _buildListView(context, channels),
                );
              },
              loading: () => _buildLoadingState(),
              error: (error, _) => _buildErrorState(context, error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildPremiumAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AppBar(
            backgroundColor: AppColors.darkBackground.withValues(alpha: 0.8),
            elevation: 0,
            title: Text(
              'Channels',
              style: TextStyle(
                color: AppColors.darkOnBackground,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              // Toggle display mode
              _PremiumIconButton(
                icon: _displayMode == ChannelDisplayMode.grid
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded,
                onTap: () {
                  setState(() {
                    _displayMode = _displayMode == ChannelDisplayMode.grid
                        ? ChannelDisplayMode.list
                        : ChannelDisplayMode.grid;
                  });
                },
                tooltip: _displayMode == ChannelDisplayMode.grid
                    ? 'List view'
                    : 'Grid view',
              ),
              _PremiumIconButton(
                icon: Icons.search_rounded,
                onTap: () => context.push(Routes.search),
                tooltip: 'Search',
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridView(BuildContext context, List<Channel> channels) {
    return ResponsiveLayout(
      mobile: _buildResponsiveGrid(context, channels, 2),
      tablet: _buildResponsiveGrid(context, channels, 4),
      desktop: _buildResponsiveGrid(context, channels, 6),
    );
  }

  Widget _buildResponsiveGrid(
      BuildContext context, List<Channel> channels, int crossAxisCount) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return ChannelCard(
          channel: channel,
          onTap: () => _playChannel(channel),
          onFavorite: () => _toggleFavorite(channel.id),
          onLongPress: () => _showChannelOptions(context, channel),
        );
      },
    );
  }

  Widget _buildListView(BuildContext context, List<Channel> channels) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return ChannelListTile(
          channel: channel,
          onTap: () => _playChannel(channel),
          onFavorite: () => _toggleFavorite(channel.id),
          onLongPress: () => _showChannelOptions(context, channel),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading channels...',
            style: TextStyle(
              color: AppColors.darkOnSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.darkSurfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.tv_off_rounded,
                size: 48,
                color: AppColors.darkOnSurfaceMuted,
              ),
            ),
            const SizedBox(height: 24),
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
              'Add a playlist to start watching your favorite channels',
              style: TextStyle(
                color: AppColors.darkOnSurfaceVariant,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _PremiumButton(
              onTap: () => context.go(Routes.playlists),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_rounded,
                    color: AppColors.darkBackground,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Add Playlist',
                    style: TextStyle(
                      color: AppColors.darkBackground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
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
                color: AppColors.darkOnSurfaceVariant,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _GlassButton(
              onTap: () {
                ref.invalidate(filteredChannelsProvider);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    color: AppColors.darkOnSurface,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Retry',
                    style: TextStyle(
                      color: AppColors.darkOnSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playChannel(Channel channel) {
    context.push('${Routes.player}?channelId=${channel.id}');
  }

  void _toggleFavorite(String channelId) {
    ref.read(favoriteNotifierProvider.notifier).toggleFavorite(channelId);
  }

  void _showChannelOptions(BuildContext context, Channel channel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPremiumOptionsSheet(context, channel),
    );
  }

  Widget _buildPremiumOptionsSheet(BuildContext context, Channel channel) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.darkSurface.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 0.5,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.darkOnSurfaceMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Channel info header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 48,
                          height: 48,
                          color: AppColors.darkSurfaceVariant,
                          child: channel.logoUrl != null
                              ? Image.network(
                                  channel.logoUrl!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.tv_rounded,
                                    color: AppColors.darkOnSurfaceMuted,
                                  ),
                                )
                              : Icon(
                                  Icons.tv_rounded,
                                  color: AppColors.darkOnSurfaceMuted,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              channel.displayName,
                              style: TextStyle(
                                color: AppColors.darkOnSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (channel.group != null)
                              Text(
                                channel.group!,
                                style: TextStyle(
                                  color: AppColors.darkOnSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.darkBorder),
                _OptionTile(
                  icon: Icons.play_arrow_rounded,
                  iconColor: AppColors.primary,
                  title: 'Play',
                  onTap: () {
                    Navigator.pop(context);
                    _playChannel(channel);
                  },
                ),
                _OptionTile(
                  icon: channel.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  iconColor: channel.isFavorite ? AppColors.accent : null,
                  title: channel.isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  onTap: () {
                    Navigator.pop(context);
                    _toggleFavorite(channel.id);
                  },
                ),
                if (channel.hasCatchup)
                  _OptionTile(
                    icon: Icons.history_rounded,
                    title: 'Catchup / Archive',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Implement catchup
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium group filter bar with horizontal scrolling
class _PremiumGroupFilterBar extends StatelessWidget {
  final List<String> groups;
  final String? selectedGroup;
  final ValueChanged<String?> onGroupSelected;

  const _PremiumGroupFilterBar({
    required this.groups,
    required this.selectedGroup,
    required this.onGroupSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: groups.length + 1, // +1 for "All" chip
        itemBuilder: (context, index) {
          if (index == 0) {
            return _FilterChip(
              label: 'All',
              isSelected: selectedGroup == null,
              onTap: () => onGroupSelected(null),
            );
          }
          final group = groups[index - 1];
          return _FilterChip(
            label: group,
            isSelected: selectedGroup == group,
            onTap: () => onGroupSelected(group),
          );
        },
      ),
    );
  }
}

/// Premium filter chip
class _FilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? AppColors.primary
                    : _isHovered
                        ? AppColors.darkSurfaceHover
                        : AppColors.darkSurfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isSelected
                      ? AppColors.primary
                      : _isHovered
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : AppColors.darkBorder,
                ),
              ),
              child: Text(
                widget.label,
                style: TextStyle(
                  color: widget.isSelected
                      ? AppColors.darkBackground
                      : AppColors.darkOnSurface,
                  fontSize: 13,
                  fontWeight:
                      widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium icon button
class _PremiumIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _PremiumIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  State<_PremiumIconButton> createState() => _PremiumIconButtonState();
}

class _PremiumIconButtonState extends State<_PremiumIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip ?? '',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isHovered
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.icon,
                color: _isHovered ? AppColors.primary : AppColors.darkOnSurface,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium gradient button
class _PremiumButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PremiumButton({
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.gradientPrimary,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Glass button
class _GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _GlassButton({
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.glassBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Option tile for bottom sheet
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.darkOnSurfaceVariant)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? AppColors.darkOnSurfaceVariant,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.darkOnSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.darkOnSurfaceMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
