import 'package:flutter/material.dart';

/// Filter chip for channel groups
class GroupFilterChip extends StatelessWidget {
  final String? group;
  final bool isSelected;
  final VoidCallback onTap;

  const GroupFilterChip({
    super.key,
    required this.group,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(group ?? 'All'),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
        checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}

/// Horizontal scrollable list of group filters
class GroupFilterBar extends StatelessWidget {
  final List<String> groups;
  final String? selectedGroup;
  final ValueChanged<String?> onGroupSelected;

  const GroupFilterBar({
    super.key,
    required this.groups,
    required this.selectedGroup,
    required this.onGroupSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // "All" chip
          GroupFilterChip(
            group: null,
            isSelected: selectedGroup == null,
            onTap: () => onGroupSelected(null),
          ),
          // Group chips
          ...groups.map(
            (group) => GroupFilterChip(
              group: group,
              isSelected: selectedGroup == group,
              onTap: () => onGroupSelected(group),
            ),
          ),
        ],
      ),
    );
  }
}
