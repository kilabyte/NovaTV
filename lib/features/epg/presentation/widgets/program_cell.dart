import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/program.dart';

/// Widget representing a single program in the EPG grid
class ProgramCell extends StatelessWidget {
  final Program program;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ProgramCell({
    super.key,
    required this.program,
    required this.width,
    required this.height,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat.jm();
    final isAiring = program.isCurrentlyAiring;
    final hasEnded = program.hasEnded;

    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.all(1),
      child: Material(
        color: _getBackgroundColor(theme, isAiring, hasEnded),
        borderRadius: BorderRadius.circular(4),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              // Progress indicator for currently airing
              if (isAiring)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: width * program.progress,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        bottomLeft: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              // Content
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      program.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: hasEnded
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Time
                    Text(
                      '${timeFormat.format(program.start)} - ${timeFormat.format(program.end)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    // Extra info if space allows
                    if (height > 50 && program.category != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          program.category!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              // Live indicator
              if (program.isLive && isAiring)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              // New indicator
              if (program.isNew)
                Positioned(
                  top: 4,
                  right: program.isLive ? 36 : 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      'NEW',
                      style: TextStyle(
                        color: theme.colorScheme.onTertiary,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor(ThemeData theme, bool isAiring, bool hasEnded) {
    if (isAiring) {
      return theme.colorScheme.primaryContainer;
    } else if (hasEnded) {
      return theme.colorScheme.surfaceContainerLow;
    }
    return theme.colorScheme.surfaceContainerHigh;
  }
}
