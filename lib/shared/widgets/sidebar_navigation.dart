import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme/app_colors.dart';

/// TiViMate-style left sidebar navigation
/// Features: Collapsible, group categories, favorites, settings access
class SidebarNavigation extends StatefulWidget {
  final List<SidebarGroup> groups;
  final String? selectedGroupId;
  final ValueChanged<String> onGroupSelected;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onFavoritesTap;
  final bool isCollapsed;
  final ValueChanged<bool>? onCollapsedChanged;

  const SidebarNavigation({
    super.key,
    required this.groups,
    this.selectedGroupId,
    required this.onGroupSelected,
    this.onSettingsTap,
    this.onSearchTap,
    this.onFavoritesTap,
    this.isCollapsed = false,
    this.onCollapsedChanged,
  });

  @override
  State<SidebarNavigation> createState() => _SidebarNavigationState();
}

class _SidebarNavigationState extends State<SidebarNavigation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _widthAnimation;

  static const double _expandedWidth = 220;
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
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void didUpdateWidget(SidebarNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCollapsed != oldWidget.isCollapsed) {
      if (widget.isCollapsed) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleCollapsed() {
    HapticFeedback.selectionClick();
    widget.onCollapsedChanged?.call(!widget.isCollapsed);
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
              right: BorderSide(
                color: AppColors.darkBorder,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Header with logo and collapse button
              _buildHeader(isExpanded),

              const SizedBox(height: 8),

              // Quick actions (Search, Favorites)
              _buildQuickActions(isExpanded),

              Divider(color: AppColors.darkDivider, height: 24),

              // Groups label
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      Text(
                        '${widget.groups.length}',
                        style: TextStyle(
                          color: AppColors.darkOnSurfaceMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // Group list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: widget.groups.length,
                  itemBuilder: (context, index) {
                    final group = widget.groups[index];
                    final isSelected = group.id == widget.selectedGroupId;
                    return _SidebarGroupItem(
                      group: group,
                      isSelected: isSelected,
                      isExpanded: isExpanded,
                      colorIndex: index,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onGroupSelected(group.id);
                      },
                    );
                  },
                ),
              ),

              Divider(color: AppColors.darkDivider, height: 1),

              // Settings button
              _buildSettingsButton(isExpanded),

              const SizedBox(height: 8),
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
          // Logo/Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(
                Icons.live_tv_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'NovaTV',
                style: TextStyle(
                  color: AppColors.darkOnSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
          // Collapse button
          IconButton(
            icon: Icon(
              isExpanded
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              color: AppColors.darkOnSurfaceVariant,
            ),
            onPressed: _toggleCollapsed,
            tooltip: isExpanded ? 'Collapse' : 'Expand',
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isExpanded) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          // Search
          _SidebarActionItem(
            icon: Icons.search_rounded,
            label: 'Search',
            isExpanded: isExpanded,
            onTap: widget.onSearchTap,
          ),
          const SizedBox(height: 4),
          // Favorites
          _SidebarActionItem(
            icon: Icons.star_rounded,
            label: 'Favorites',
            isExpanded: isExpanded,
            iconColor: AppColors.favorite,
            onTap: widget.onFavoritesTap,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsButton(bool isExpanded) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: _SidebarActionItem(
        icon: Icons.settings_rounded,
        label: 'Settings',
        isExpanded: isExpanded,
        onTap: widget.onSettingsTap,
      ),
    );
  }
}

/// Sidebar group data model
class SidebarGroup {
  final String id;
  final String name;
  final IconData? icon;
  final int channelCount;
  final bool isPinned;

  const SidebarGroup({
    required this.id,
    required this.name,
    this.icon,
    this.channelCount = 0,
    this.isPinned = false,
  });
}

/// Individual group item in sidebar
class _SidebarGroupItem extends StatefulWidget {
  final SidebarGroup group;
  final bool isSelected;
  final bool isExpanded;
  final int colorIndex;
  final VoidCallback onTap;

  const _SidebarGroupItem({
    required this.group,
    required this.isSelected,
    required this.isExpanded,
    required this.colorIndex,
    required this.onTap,
  });

  @override
  State<_SidebarGroupItem> createState() => _SidebarGroupItemState();
}

class _SidebarGroupItemState extends State<_SidebarGroupItem> {
  bool _isHovered = false;

  Color get _accentColor =>
      AppColors.groupColors[widget.colorIndex % AppColors.groupColors.length];

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 4),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isExpanded ? 12 : 0,
            vertical: 10,
          ),
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
          child: widget.isExpanded
              ? Row(
                  children: [
                    // Color indicator
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? AppColors.primary
                            : _accentColor.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Icon
                    Icon(
                      widget.group.icon ?? Icons.folder_rounded,
                      color: widget.isSelected
                          ? AppColors.primary
                          : AppColors.darkOnSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    // Name
                    Expanded(
                      child: Text(
                        widget.group.name,
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
                    // Channel count
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : AppColors.darkSurfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.group.channelCount}',
                        style: TextStyle(
                          color: widget.isSelected
                              ? AppColors.primary
                              : AppColors.darkOnSurfaceMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Pin indicator
                    if (widget.group.isPinned) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.push_pin_rounded,
                        size: 14,
                        color: AppColors.darkOnSurfaceMuted,
                      ),
                    ],
                  ],
                )
              : Center(
                  child: Tooltip(
                    message: '${widget.group.name} (${widget.group.channelCount})',
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? AppColors.sidebarSelectedBg
                            : _isHovered
                                ? AppColors.sidebarHover
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: widget.isSelected
                              ? AppColors.primary
                              : _accentColor.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          widget.group.name.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: widget.isSelected
                                ? AppColors.primary
                                : _accentColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Quick action item (Search, Favorites, Settings)
class _SidebarActionItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isExpanded;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _SidebarActionItem({
    required this.icon,
    required this.label,
    required this.isExpanded,
    this.iconColor,
    this.onTap,
  });

  @override
  State<_SidebarActionItem> createState() => _SidebarActionItemState();
}

class _SidebarActionItemState extends State<_SidebarActionItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap?.call();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isExpanded ? 12 : 0,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.sidebarHover : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: widget.isExpanded
              ? Row(
                  children: [
                    Icon(
                      widget.icon,
                      color: widget.iconColor ?? AppColors.darkOnSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: AppColors.darkOnSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Tooltip(
                    message: widget.label,
                    child: Icon(
                      widget.icon,
                      color: widget.iconColor ?? AppColors.darkOnSurfaceVariant,
                      size: 22,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
