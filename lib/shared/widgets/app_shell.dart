import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/router/routes.dart';
import '../../config/theme/app_colors.dart';
import '../../core/utils/app_logger.dart';
import '../../features/epg/presentation/providers/epg_providers.dart';
import '../../features/player/presentation/providers/player_providers.dart';
import '../../features/player/presentation/widgets/mini_player.dart';
import '../../features/playlist/presentation/providers/playlist_providers.dart';
import '../../features/settings/presentation/providers/settings_providers.dart';
import 'responsive_layout.dart';

/// Provider to track pinned groups
final pinnedGroupsProvider = StateProvider<Set<String>>((ref) => {});

/// Clean modern app shell
/// Desktop: Left sidebar with groups, main content area
/// Mobile: Bottom tab navigation
class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _mobileSelectedIndex = 0;
  bool _hasCheckedAutoRefresh = false;

  @override
  void initState() {
    super.initState();
    // Check for auto-refresh on app startup (delayed to allow providers to initialize)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoRefresh();
    });
  }

  /// Check if playlists or EPG need auto-refresh on app startup
  Future<void> _checkAutoRefresh() async {
    if (_hasCheckedAutoRefresh) return;
    _hasCheckedAutoRefresh = true;

    AppLogger.info('Checking for auto-refresh on startup...');

    // Get all playlists
    final playlistsAsync = ref.read(playlistsProvider);

    playlistsAsync.whenData((playlists) async {
      for (final playlist in playlists) {
        // Check if playlist needs refresh
        if (playlist.autoRefresh && playlist.needsRefresh) {
          AppLogger.info('Auto-refreshing playlist: ${playlist.name}');
          await ref.read(playlistNotifierProvider.notifier).refreshPlaylist(playlist.id);
        }

        // Check if EPG needs refresh
        if (playlist.hasEpg && playlist.autoRefresh && playlist.needsRefresh) {
          AppLogger.info('Auto-refreshing EPG for playlist: ${playlist.name}');
          await ref.read(epgRefreshNotifierProvider.notifier).refreshEpg(
            playlist.id,
            playlist.epgUrl!,
          );
        }
      }
    });
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith(Routes.channels)) return 0;
    if (location.startsWith(Routes.tvGuide)) return 1;
    if (location.startsWith(Routes.favorites)) return 2;
    if (location.startsWith(Routes.playlists)) return 3;
    if (location.startsWith(Routes.settings)) return 4;
    if (location.startsWith(Routes.search)) return 5;
    if (location == Routes.home) return 0; // Home redirects to channels
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    HapticFeedback.selectionClick();
    String? routeToSave;
    switch (index) {
      case 0:
        context.go(Routes.channels);
        routeToSave = Routes.channels;
        break;
      case 1:
        context.go(Routes.tvGuide);
        routeToSave = Routes.tvGuide;
        break;
      case 2:
        context.go(Routes.favorites);
        routeToSave = Routes.favorites;
        break;
      case 3:
        context.go(Routes.playlists);
        routeToSave = Routes.playlists;
        break;
      case 4:
        context.go(Routes.settings);
        routeToSave = Routes.settings;
        break;
      case 5:
        context.push(Routes.search);
        // Don't save search as it's a modal/overlay
        break;
    }
    // Persist the selected route (except search)
    if (routeToSave != null) {
      ref.read(appSettingsProvider.notifier).setLastSelectedSidebarRoute(routeToSave);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final newIndex = _calculateSelectedIndex(context);
      if (newIndex <= 2 && newIndex != _mobileSelectedIndex) {
        setState(() => _mobileSelectedIndex = newIndex);
      }
    });

    return ResponsiveLayout(
      mobile: _buildMobileLayout(context),
      tablet: _buildDesktopLayout(context),
      desktop: _buildDesktopLayout(context),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          widget.child,
          // Mini-player overlay
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: _MobileNavBar(
        selectedIndex: _mobileSelectedIndex,
        onTap: (index) {
          setState(() => _mobileSelectedIndex = index);
          _onItemTapped(context, index);
        },
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Row(
            children: [
              // Sidebar
              _DesktopSidebar(
                selectedIndex: selectedIndex,
                onItemTapped: (index) => _onItemTapped(context, index),
              ),
              // Divider
              Container(width: 1, color: AppColors.border),
              // Main content
              Expanded(child: widget.child),
            ],
          ),
          // Mini-player overlay
          const MiniPlayer(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DESKTOP SIDEBAR - Clean macOS-style
// ═══════════════════════════════════════════════════════════════════════════

class _DesktopSidebar extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const _DesktopSidebar({
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 220,
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App header
          _SidebarHeader(),

          const SizedBox(height: 8),

          // Main navigation
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                // TV Guide - prominent position at top
                _SidebarItemLarge(
                  icon: Icons.calendar_month_rounded,
                  label: 'TV Guide',
                  isSelected: selectedIndex == 1,
                  onTap: () => onItemTapped(1),
                ),

                const SizedBox(height: 4),

                // Primary items
                _SidebarItem(
                  icon: Icons.star_rounded,
                  label: 'Favorites',
                  isSelected: selectedIndex == 2,
                  onTap: () => onItemTapped(2),
                ),

                // Recently Watched section
                _RecentlyWatchedSection(),

                // Divider
                _SidebarDivider(),

                // Groups section (collapsible)
                _GroupsSection(
                  onGroupTap: (group) {
                    ref.read(selectedGroupProvider.notifier).state = group;
                    onItemTapped(0);
                  },
                ),

                // Divider
                _SidebarDivider(),

                // Secondary items
                _SidebarItem(
                  icon: Icons.search_rounded,
                  label: 'Search',
                  isSelected: selectedIndex == 5,
                  onTap: () => onItemTapped(5),
                ),
                _SidebarItem(
                  icon: Icons.playlist_add_rounded,
                  label: 'Playlists',
                  isSelected: selectedIndex == 3,
                  onTap: () => onItemTapped(3),
                ),
              ],
            ),
          ),

          // Settings at bottom
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.all(8),
            child: _SidebarItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              isSelected: selectedIndex == 4,
              onTap: () => onItemTapped(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Simple icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.live_tv_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'NovaIPTV',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: AppColors.border,
    );
  }
}

/// Recently watched channels section with collapsible list
class _RecentlyWatchedSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_RecentlyWatchedSection> createState() =>
      _RecentlyWatchedSectionState();
}

class _RecentlyWatchedSectionState
    extends ConsumerState<_RecentlyWatchedSection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final recentChannelsAsync = ref.watch(recentlyWatchedChannelsProvider);

    return recentChannelsAsync.when(
      data: (channels) {
        if (channels.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header with expand/collapse
            _RecentlyWatchedHeader(
              isExpanded: _isExpanded,
              onToggle: () => setState(() => _isExpanded = !_isExpanded),
            ),

            // Channel list (when expanded)
            if (_isExpanded)
              ...channels.take(5).map((channel) => _RecentChannelItem(
                    channelName: channel.displayName,
                    onTap: () {
                      ref.read(playerProvider.notifier).playChannel(channel.id);
                      context.push(Routes.playerPath(channel.id));
                    },
                  )),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RecentlyWatchedHeader extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggle;

  const _RecentlyWatchedHeader({
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<_RecentlyWatchedHeader> createState() => _RecentlyWatchedHeaderState();
}

class _RecentlyWatchedHeaderState extends State<_RecentlyWatchedHeader> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onToggle,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: _isHovered
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Recently Watched',
                  style: TextStyle(
                    color: _isHovered
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: widget.isExpanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentChannelItem extends StatefulWidget {
  final String channelName;
  final VoidCallback onTap;

  const _RecentChannelItem({
    required this.channelName,
    required this.onTap,
  });

  @override
  State<_RecentChannelItem> createState() => _RecentChannelItemState();
}

/// Groups section with collapsible list (persists expansion state)
class _GroupsSection extends ConsumerWidget {
  final void Function(String group) onGroupTap;

  const _GroupsSection({required this.onGroupTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(channelGroupsProvider);
    final pinnedGroups = ref.watch(pinnedGroupsProvider);
    final settings = ref.watch(appSettingsProvider);
    final isExpanded = settings.groupsSectionExpanded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with expand/collapse
        _GroupsSectionHeader(
          isExpanded: isExpanded,
          onToggle: () {
            ref.read(appSettingsProvider.notifier).setGroupsSectionExpanded(!isExpanded);
          },
        ),

        // Groups list (when expanded)
        if (isExpanded)
          groupsAsync.when(
            data: (groups) {
              final pinned = groups.where((g) => pinnedGroups.contains(g)).toList();
              final unpinned = groups.where((g) => !pinnedGroups.contains(g)).toList();
              final selectedGroup = ref.watch(selectedGroupProvider);

              return Column(
                children: [
                  // Pinned groups
                  ...pinned.map((group) => _SidebarGroupItem(
                    group: group,
                    isPinned: true,
                    isSelected: selectedGroup == group,
                    onTap: () => onGroupTap(group),
                    onPinToggle: () {
                      final current = ref.read(pinnedGroupsProvider);
                      ref.read(pinnedGroupsProvider.notifier).state =
                        current.contains(group)
                          ? current.difference({group})
                          : current.union({group});
                    },
                  )),

                  // All unpinned groups (scrollable)
                  ...unpinned.map((group) => _SidebarGroupItem(
                    group: group,
                    isPinned: false,
                    isSelected: selectedGroup == group,
                    onTap: () => onGroupTap(group),
                    onPinToggle: () {
                      final current = ref.read(pinnedGroupsProvider);
                      ref.read(pinnedGroupsProvider.notifier).state =
                        current.union({group});
                    },
                  )),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
            error: (_, __) => const SizedBox(),
          ),
      ],
    );
  }
}

class _GroupsSectionHeader extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggle;

  const _GroupsSectionHeader({
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<_GroupsSectionHeader> createState() => _GroupsSectionHeaderState();
}

class _GroupsSectionHeaderState extends State<_GroupsSectionHeader> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onToggle,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_rounded,
                color: _isHovered
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Groups',
                  style: TextStyle(
                    color: _isHovered
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: widget.isExpanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentChannelItemState extends State<_RecentChannelItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2, left: 20),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _isHovered ? AppColors.primary : AppColors.textMuted,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.channelName,
                  style: TextStyle(
                    color: _isHovered
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
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

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = _isHovered || widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.sidebarSelectedBg
                : _isHovered
                    ? AppColors.surfaceHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.isSelected
                    ? AppColors.primary
                    : isHighlighted
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isSelected
                        ? AppColors.textPrimary
                        : isHighlighted
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: widget.isSelected ? FontWeight.w500 : FontWeight.w400,
                  ),
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

/// Larger sidebar item for prominent navigation items like TV Guide
class _SidebarItemLarge extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItemLarge({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarItemLarge> createState() => _SidebarItemLargeState();
}

class _SidebarItemLargeState extends State<_SidebarItemLarge> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = _isHovered || widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.sidebarSelectedBg
                : _isHovered
                    ? AppColors.surfaceHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.isSelected
                    ? AppColors.primary
                    : isHighlighted
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isSelected
                        ? AppColors.textPrimary
                        : isHighlighted
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
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

class _SidebarGroupItem extends StatefulWidget {
  final String group;
  final bool isPinned;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onPinToggle;

  const _SidebarGroupItem({
    required this.group,
    required this.isPinned,
    required this.isSelected,
    required this.onTap,
    required this.onPinToggle,
  });

  @override
  State<_SidebarGroupItem> createState() => _SidebarGroupItemState();
}

class _SidebarGroupItemState extends State<_SidebarGroupItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = _isHovered || widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.sidebarSelectedBg
                : _isHovered
                    ? AppColors.surfaceHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Group indicator - RED when selected
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? AppColors.live // Red color for selected
                      : widget.isPinned
                          ? AppColors.primary
                          : AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.group,
                  style: TextStyle(
                    color: widget.isSelected
                        ? AppColors.textPrimary
                        : isHighlighted
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: widget.isSelected ? FontWeight.w500 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Pin button on hover
              if (_isHovered)
                GestureDetector(
                  onTap: widget.onPinToggle,
                  child: Icon(
                    widget.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    size: 14,
                    color: widget.isPinned ? AppColors.primary : AppColors.textMuted,
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
// MOBILE NAV BAR - Clean bottom navigation
// ═══════════════════════════════════════════════════════════════════════════

class _MobileNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _MobileNavBar({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MobileNavItem(
                icon: Icons.live_tv_rounded,
                label: 'Live',
                isSelected: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
              _MobileNavItem(
                icon: Icons.calendar_month_rounded,
                label: 'Guide',
                isSelected: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
              _MobileNavItem(
                icon: Icons.star_rounded,
                label: 'Favorites',
                isSelected: selectedIndex == 2,
                onTap: () => onTap(2),
              ),
              _MobileNavItem(
                icon: Icons.more_horiz_rounded,
                label: 'More',
                isSelected: false,
                onTap: () => _showMoreSheet(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _MoreSheetItem(
              icon: Icons.playlist_play_rounded,
              label: 'Playlists',
              onTap: () {
                Navigator.pop(context);
                context.go(Routes.playlists);
              },
            ),
            _MoreSheetItem(
              icon: Icons.search_rounded,
              label: 'Search',
              onTap: () {
                Navigator.pop(context);
                context.push(Routes.search);
              },
            ),
            _MoreSheetItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              onTap: () {
                Navigator.pop(context);
                context.go(Routes.settings);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreSheetItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MoreSheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
