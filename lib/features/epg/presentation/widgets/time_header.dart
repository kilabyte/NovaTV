import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Time header widget for the TV Guide showing hours
class TimeHeader extends StatelessWidget {
  final ScrollController scrollController;
  final DateTime startTime;
  final int hoursToShow;
  final double hourWidth;
  final double channelColumnWidth;

  const TimeHeader({
    super.key,
    required this.scrollController,
    required this.startTime,
    this.hoursToShow = 24,
    this.hourWidth = 200,
    this.channelColumnWidth = 120,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat.j();
    final theme = Theme.of(context);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Channel column placeholder
          SizedBox(
            width: channelColumnWidth,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                border: Border(
                  right: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  'Channels',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          // Time slots
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: hoursToShow,
              itemBuilder: (context, index) {
                final time = startTime.add(Duration(hours: index));
                final isCurrentHour = _isCurrentHour(time);

                return Container(
                  width: hourWidth,
                  decoration: BoxDecoration(
                    color: isCurrentHour
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    border: Border(
                      right: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Time label
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          timeFormat.format(time),
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: isCurrentHour ? FontWeight.bold : FontWeight.normal,
                            color: isCurrentHour
                                ? theme.colorScheme.onPrimaryContainer
                                : null,
                          ),
                        ),
                      ),
                      // 30-minute mark
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 1,
                            height: 8,
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isCurrentHour(DateTime time) {
    final now = DateTime.now();
    return time.year == now.year &&
        time.month == now.month &&
        time.day == now.day &&
        time.hour == now.hour;
  }
}
