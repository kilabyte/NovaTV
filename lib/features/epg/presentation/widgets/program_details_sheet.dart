import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/program.dart';

/// Bottom sheet showing program details
class ProgramDetailsSheet extends StatelessWidget {
  final Program program;
  final VoidCallback? onWatchNow;
  final VoidCallback? onSetReminder;

  const ProgramDetailsSheet({
    super.key,
    required this.program,
    this.onWatchNow,
    this.onSetReminder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();
    final timeFormat = DateFormat.jm();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Title and badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  program.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (program.isLive && program.isCurrentlyAiring)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (program.isNew)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'NEW',
                      style: TextStyle(
                        color: theme.colorScheme.onTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Subtitle
          if (program.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              program.subtitle!,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Time info
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${dateFormat.format(program.start)} • ${timeFormat.format(program.start)} - ${timeFormat.format(program.end)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          // Duration
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${program.durationMinutes} minutes',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          // Progress for currently airing
          if (program.isCurrentlyAiring) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Now playing',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(program.progress * 100).toInt()}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: program.progress,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          ],
          // Category
          if (program.category != null) ...[
            const SizedBox(height: 12),
            Chip(
              label: Text(program.category!),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              side: BorderSide.none,
            ),
          ],
          // Episode number
          if (program.episodeNum != null) ...[
            const SizedBox(height: 8),
            Text(
              'Episode: ${program.episodeNum}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          // Rating
          if (program.rating != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.star_border,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Rating: ${program.rating}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          // Description
          if (program.description != null) ...[
            const SizedBox(height: 16),
            Text(
              program.description!,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          // Actions
          const SizedBox(height: 24),
          Row(
            children: [
              if (program.isCurrentlyAiring && onWatchNow != null)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onWatchNow,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Watch Now'),
                  ),
                ),
              if (!program.isCurrentlyAiring && program.isUpcoming && onSetReminder != null) ...[
                if (program.isCurrentlyAiring) const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSetReminder,
                    icon: const Icon(Icons.notifications_outlined),
                    label: const Text('Remind Me'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
