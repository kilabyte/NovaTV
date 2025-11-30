import 'package:flutter/material.dart';

import '../../../playlist/domain/entities/channel.dart';
import '../../domain/entities/program.dart';
import 'program_cell.dart';

/// Grid widget showing programs for all channels
class ProgramGrid extends StatelessWidget {
  final ScrollController horizontalController;
  final ScrollController verticalController;
  final List<Channel> channels;
  final Map<String, List<Program>> programsByChannel;
  final DateTime startTime;
  final int hoursToShow;
  final double hourWidth;
  final double rowHeight;
  final void Function(Program)? onProgramTap;
  final void Function(Program)? onProgramLongPress;

  const ProgramGrid({
    super.key,
    required this.horizontalController,
    required this.verticalController,
    required this.channels,
    required this.programsByChannel,
    required this.startTime,
    this.hoursToShow = 24,
    this.hourWidth = 200,
    this.rowHeight = 60,
    this.onProgramTap,
    this.onProgramLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalWidth = hourWidth * hoursToShow;
    final endTime = startTime.add(Duration(hours: hoursToShow));

    return ListView.builder(
      controller: verticalController,
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        final programs = programsByChannel[channel.tvgId] ??
                         programsByChannel[channel.id] ??
                         [];

        return Container(
          height: rowHeight,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
          ),
          child: SingleChildScrollView(
            controller: horizontalController,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: totalWidth,
              child: _buildChannelRow(
                context,
                programs,
                startTime,
                endTime,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChannelRow(
    BuildContext context,
    List<Program> programs,
    DateTime gridStart,
    DateTime gridEnd,
  ) {
    final theme = Theme.of(context);

    // Filter and sort programs that overlap with our time range
    final visiblePrograms = programs
        .where((p) => p.end.isAfter(gridStart) && p.start.isBefore(gridEnd))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    if (visiblePrograms.isEmpty) {
      // Show empty placeholder
      return Container(
        color: theme.colorScheme.surfaceContainerLow,
        child: Center(
          child: Text(
            'No program data',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final widgets = <Widget>[];
    var currentTime = gridStart;

    for (final program in visiblePrograms) {
      // Add gap before program if needed
      if (program.start.isAfter(currentTime)) {
        final gapDuration = program.start.difference(currentTime);
        final gapWidth = _durationToWidth(gapDuration);
        if (gapWidth > 0) {
          widgets.add(
            SizedBox(
              width: gapWidth,
              height: rowHeight - 2,
              child: Container(
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          );
        }
      }

      // Calculate program cell width
      final displayStart = program.start.isBefore(gridStart) ? gridStart : program.start;
      final displayEnd = program.end.isAfter(gridEnd) ? gridEnd : program.end;
      final duration = displayEnd.difference(displayStart);
      final cellWidth = _durationToWidth(duration);

      if (cellWidth > 0) {
        widgets.add(
          ProgramCell(
            program: program,
            width: cellWidth,
            height: rowHeight - 2,
            onTap: onProgramTap != null ? () => onProgramTap!(program) : null,
            onLongPress: onProgramLongPress != null ? () => onProgramLongPress!(program) : null,
          ),
        );
      }

      currentTime = program.end;
    }

    // Add trailing gap if needed
    if (currentTime.isBefore(gridEnd)) {
      final gapDuration = gridEnd.difference(currentTime);
      final gapWidth = _durationToWidth(gapDuration);
      if (gapWidth > 0) {
        widgets.add(
          SizedBox(
            width: gapWidth,
            height: rowHeight - 2,
            child: Container(
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );
      }
    }

    return Row(children: widgets);
  }

  double _durationToWidth(Duration duration) {
    return (duration.inMinutes / 60.0) * hourWidth;
  }
}
