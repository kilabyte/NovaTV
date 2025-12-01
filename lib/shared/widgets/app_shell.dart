import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../config/router/routes.dart';
import '../../config/theme/app_colors.dart';
import 'responsive_layout.dart';

/// TiViMate-style app shell with left sidebar navigation
/// Desktop/Tablet: Left sidebar with groups
/// Mobile: Bottom navigation bar (compact)
class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _isSidebarCollapsed = false;

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith(Routes.home) && location == Routes.home) return 0;
    if (location.startsWith(Routes.channels)) return 1;
    if (location.startsWith(Routes.tvGuide)) return 2;
    if (location.startsWith(Routes.favorites)) return 3;
    if (location.startsWith(Routes.playlists)) return 4;
    if (location.startsWith(Routes.settings)) return 5;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    HapticFeedback.selectionClick();
    switch (index) {
      case 0:
        context.go(Routes.home);
        break;
      case 1:
        context.go(Routes.channels);
        break;
      case 2:
        context.go(Routes.tvGuide);
        break;
      case 3:
        context.go(Routes.favorites);
        break;
      case 4:
        context.go(Routes.playlists);
        break;
      case 5:
        context.go(Routes.settings);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileLayout(context),
      tablet: _buildDesktopLayout(context),
      desktop: _buildDesktopLayout(context),
    );
  }

  /// Mobile layout with bottom navigation - compact TiViMate style
  Widget _buildMobileLayout(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.darkSidebar,
          border: Border(
            top: BorderSide(color: AppColors.darkBorder, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MobileNavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: selectedIndex == 0,
                  onTap: () => _onItemTapped(context, 0),
                ),
                _MobileNavItem(
                  icon: Icons.live_tv_rounded,
                  label: 'Live',
                  isSelected: selectedIndex == 1,
                  onTap: () => _onItemTapped(context, 1),
                ),
                _MobileNavItem(
                  icon: Icons.calendar_month_rounded,
                  label: 'Guide',
                  isSelected: selectedIndex == 2,
                  onTap: () => _onItemTapped(context, 2),
                ),
                _MobileNavItem(
                  icon: Icons.star_rounded,
                  label: 'Favorites',
                  isSelected: selectedIndex == 3,
                  onTap: () => _onItemTapped(context, 3),
                ),
                _MobileNavItem(
                  icon: Icons.more_horiz_rounded,
                  label: 'More',
                  isSelected: selectedIndex >= 4,
                  onTap: () => _showMoreMenu(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Desktop/Tablet layout with TiViMate-style left sidebar
  Widget _buildDesktopLayout(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Row(
        children: [
          // Left Sidebar Navigation
          _DesktopSidebar(
            selectedIndex: selectedIndex,
            isCollapsed: _isSidebarCollapsed,
            onItemTapped: (index) => _onItemTapped(context, index),
            onSearchTap: () => context.push(Routes.search),
            onCollapsedChanged: (collapsed) {
              setState(() => _isSidebarCollapsed = collapsed);
            },
          ),
          // Main Content
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _MoreMenuItem(
              icon: Icons.playlist_play_rounded,
              label: 'Playlists',
              onTap: () {
                Navigator.pop(context);
                context.go(Routes.playlists);
              },
            ),
            _MoreMenuItem(
              icon: Icons.search_rounded,
              label: 'Search',
              onTap: () {
                Navigator.pop(context);
                context.push(Routes.search);
              },
            ),
            _MoreMenuItem(
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

/// Mobile bottom navigation item
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.darkOnSurfaceMuted,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.darkOnSurfaceMuted,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// More menu item
class _MoreMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MoreMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.darkOnSurface),
      title: Text(
        label,
        style: TextStyle(color: AppColors.darkOnSurface),
      ),
      onTap: onTap,
    );
  }
}

/// Desktop sidebar navigation - TiViMate style
class _DesktopSidebar extends StatefulWidget {
  final int selectedIndex;
  final bool isCollapsed;
  final ValueChanged<int> onItemTapped;
  final VoidCallback onSearchTap;
  final ValueChanged<bool> onCollapsedChanged;

  const _DesktopSidebar({
    required this.selectedIndex,
    required this.isCollapsed,
    required this.onItemTapped,
    required this.onSearchTap,
    required this.onCollapsedChanged,
  });

  @override
  State<_DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<_DesktopSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _widthAnimation;

  static const double _expandedWidth = 200;
  static const double _collapsedWidth = 72;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: widget.isCollapsed ? 0.0 : 1.0,
    );
    _widthAnimation = Tween<double>(
      begin: _collapsedWidth,
      end: _expandedWidth,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(_DesktopSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCollapsed != oldWidget.isCollapsed) {
      widget.isCollapsed ? _controller.reverse() : _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        final isExpanded = _widthAnimation.value > _collapsedWidth + 20;

        return Container(
          width: _widthAnimation.value,
          decoration: BoxDecoration(
            color: AppColors.darkSidebar,
            border: Border(
              right: BorderSide(color: AppColors.darkBorder, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Header
              _buildHeader(isExpanded),
              const SizedBox(height: 16),

              // Navigation items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    _SidebarNavItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      isSelected: widget.selectedIndex == 0,
                      isExpanded: isExpanded,
                      onTap: () => widget.onItemTapped(0),
                    ),
                    _SidebarNavItem(
                      icon: Icons.live_tv_rounded,
                      label: 'Live TV',
                      isSelected: widget.selectedIndex == 1,
                      isExpanded: isExpanded,
                      onTap: () => widget.onItemTapped(1),
                    ),
                    _SidebarNavItem(
                      icon: Icons.calendar_month_rounded,
                      label: 'TV Guide',
                      isSelected: widget.selectedIndex == 2,
                      isExpanded: isExpanded,
                      onTap: () => widget.onItemTapped(2),
                    ),
                    _SidebarNavItem(
                      icon: Icons.star_rounded,
                      label: 'Favorites',
                      isSelected: widget.selectedIndex == 3,
                      isExpanded: isExpanded,
                      accentColor: AppColors.favorite,
                      onTap: () => widget.onItemTapped(3),
                    ),

                    Divider(color: AppColors.darkDivider, height: 32),

                    _SidebarNavItem(
                      icon: Icons.playlist_play_rounded,
                      label: 'Playlists',
                      isSelected: widget.selectedIndex == 4,
                      isExpanded: isExpanded,
                      onTap: () => widget.onItemTapped(4),
                    ),
                    _SidebarNavItem(
                      icon: Icons.search_rounded,
                      label: 'Search',
                      isSelected: false,
                      isExpanded: isExpanded,
                      onTap: widget.onSearchTap,
                    ),
                  ],
                ),
              ),

              Divider(color: AppColors.darkDivider, height: 1),

              // Settings at bottom
              Padding(
                padding: const EdgeInsets.all(8),
                child: _SidebarNavItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isSelected: widget.selectedIndex == 5,
                  isExpanded: isExpanded,
                  onTap: () => widget.onItemTapped(5),
                ),
              ),

              // Collapse toggle
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                child: _SidebarNavItem(
                  icon: isExpanded
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  label: isExpanded ? 'Collapse' : 'Expand',
                  isSelected: false,
                  isExpanded: isExpanded,
                  onTap: () => widget.onCollapsedChanged(!widget.isCollapsed),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isExpanded) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.live_tv_rounded, color: Colors.white, size: 22),
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(width: 12),
            Text(
              'NovaTV',
              style: TextStyle(
                color: AppColors.darkOnSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Individual sidebar navigation item
class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isExpanded;
  final Color? accentColor;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isExpanded,
    this.accentColor,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.accentColor ?? AppColors.primary;

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
          padding: EdgeInsets.symmetric(
            horizontal: widget.isExpanded ? 12 : 0,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? activeColor.withValues(alpha: 0.15)
                : _isHovered
                    ? AppColors.sidebarHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: widget.isSelected
                ? Border.all(color: activeColor.withValues(alpha: 0.3))
                : null,
          ),
          child: widget.isExpanded
              ? Row(
                  children: [
                    Icon(
                      widget.icon,
                      color: widget.isSelected
                          ? activeColor
                          : _isHovered
                              ? AppColors.darkOnSurface
                              : AppColors.darkOnSurfaceVariant,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: widget.isSelected
                              ? AppColors.darkOnSurface
                              : AppColors.darkOnSurfaceVariant,
                          fontSize: 14,
                          fontWeight: widget.isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (widget.isSelected)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: activeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                )
              : Center(
                  child: Tooltip(
                    message: widget.label,
                    child: Icon(
                      widget.icon,
                      color: widget.isSelected
                          ? activeColor
                          : _isHovered
                              ? AppColors.darkOnSurface
                              : AppColors.darkOnSurfaceVariant,
                      size: 24,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
