import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

import '../../../../config/router/routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../playlist/domain/entities/channel.dart';
import '../../../playlist/presentation/providers/playlist_providers.dart';
import '../../domain/entities/program.dart';
import '../providers/epg_providers.dart';
import '../widgets/program_details_sheet.dart';

/// Premium TV Guide screen with cinematic EPG grid
class TvGuideScreen extends ConsumerStatefulWidget {
  const TvGuideScreen({super.key});

  @override
  ConsumerState<TvGuideScreen> createState() => _TvGuideScreenState();
}

class _TvGuideScreenState extends ConsumerState<TvGuideScreen> {
  late LinkedScrollControllerGroup _horizontalControllerGroup;
  late ScrollController _timeHeaderController;
  late ScrollController _programGridController;

  late LinkedScrollControllerGroup _verticalControllerGroup;
  late ScrollController _channelColumnController;
  late ScrollController _programGridVerticalController;

  static const double _hourWidth = 220;
  static const double _rowHeight = 72;
  static const double _channelColumnWidth = 140;
  static const int _hoursToShow = 24;

  @override
  void initState() {
    super.initState();

    _horizontalControllerGroup = LinkedScrollControllerGroup();
    _timeHeaderController = _horizontalControllerGroup.addAndGet();
    _programGridController = _horizontalControllerGroup.addAndGet();

    _verticalControllerGroup = LinkedScrollControllerGroup();
    _channelColumnController = _verticalControllerGroup.addAndGet();
    _programGridVerticalController = _verticalControllerGroup.addAndGet();

    // Scroll to current time on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentTime();
    });
  }

  void _scrollToCurrentTime() {
    final now = DateTime.now();
    final selectedDate = ref.read(selectedDateProvider);
    final startTime =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final hoursSinceStart = now.difference(startTime).inMinutes / 60.0;

    if (hoursSinceStart >= 0 && hoursSinceStart < _hoursToShow) {
      final offset = (hoursSinceStart * _hourWidth) - (_hourWidth * 2);
      if (_timeHeaderController.hasClients) {
        _timeHeaderController.animateTo(
          offset.clamp(0.0, (_hoursToShow * _hourWidth) - 400.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _timeHeaderController.dispose();
    _programGridController.dispose();
    _channelColumnController.dispose();
    _programGridVerticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(allChannelsProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final startTime =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      extendBodyBehindAppBar: true,
      appBar: _buildPremiumAppBar(context),
      body: Column(
        children: [
          SizedBox(
              height: MediaQuery.of(context).padding.top + kToolbarHeight + 48),
          // Main content
          Expanded(
            child: channelsAsync.when(
              data: (channels) {
                if (channels.isEmpty) {
                  return _buildEmptyState(context);
                }
                return _buildTvGuide(context, channels, startTime);
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
    final selectedDate = ref.watch(selectedDateProvider);

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 48),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.darkBackground.withValues(alpha: 0.8),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.darkBorder,
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App bar - no back button since this is a tab
                  SizedBox(
                    height: kToolbarHeight,
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'TV Guide',
                            style: TextStyle(
                              color: AppColors.darkOnBackground,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        _PremiumIconButton(
                          icon: Icons.today_rounded,
                          onTap: () => _showDatePicker(context),
                          tooltip: 'Select date',
                        ),
                        _PremiumIconButton(
                          icon: Icons.my_location_rounded,
                          onTap: _scrollToCurrentTime,
                          tooltip: 'Go to now',
                        ),
                        _PremiumIconButton(
                          icon: Icons.refresh_rounded,
                          onTap: () => _refreshEpg(context),
                          tooltip: 'Refresh EPG',
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  // Date selector
                  _buildDateSelector(context, selectedDate),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context, DateTime selectedDate) {
    final dateFormat = DateFormat.E();
    final dates = List.generate(7, (i) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day).add(Duration(days: i - 1));
    });

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = date.year == selectedDate.year &&
              date.month == selectedDate.month &&
              date.day == selectedDate.day;
          final isToday = date.year == DateTime.now().year &&
              date.month == DateTime.now().month &&
              date.day == DateTime.now().day;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _DateChip(
              date: date,
              label: isToday ? 'Today' : dateFormat.format(date),
              isSelected: isSelected,
              onTap: () {
                ref.read(selectedDateProvider.notifier).state = date;
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTvGuide(
      BuildContext context, List<Channel> channels, DateTime startTime) {
    final playlists = ref.watch(playlistNotifierProvider);
    final playlistId = playlists.valueOrNull?.firstOrNull?.id ?? '';

    return FutureBuilder<Map<String, List<Program>>>(
      future: _getProgramsForChannels(playlistId, channels, startTime),
      builder: (context, snapshot) {
        final programsByChannel = snapshot.data ?? {};

        return Column(
          children: [
            // Time header
            _buildTimeHeader(context, startTime),
            // Main content
            Expanded(
              child: Row(
                children: [
                  // Channel column
                  _buildChannelColumn(context, channels),
                  // Program grid
                  Expanded(
                    child: _buildProgramGrid(
                      context,
                      channels,
                      programsByChannel,
                      startTime,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimeHeader(BuildContext context, DateTime startTime) {
    final timeFormat = DateFormat.j();

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.darkBorder,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Channel column placeholder
          Container(
            width: _channelColumnWidth,
            decoration: BoxDecoration(
              color: AppColors.epgTimeHeader,
              border: Border(
                right: BorderSide(
                  color: AppColors.darkBorder,
                  width: 0.5,
                ),
              ),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.live_tv_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Channels',
                    style: TextStyle(
                      color: AppColors.darkOnSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Time slots
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _timeHeaderController,
                  scrollDirection: Axis.horizontal,
                  itemCount: _hoursToShow,
                  itemBuilder: (context, index) {
                    final time = startTime.add(Duration(hours: index));
                    final isCurrentHour = _isCurrentHour(time);

                    return Container(
                      width: _hourWidth,
                      decoration: BoxDecoration(
                        color: isCurrentHour
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.epgTimeHeader,
                        border: Border(
                          right: BorderSide(
                            color: AppColors.darkBorder,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              timeFormat.format(time),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isCurrentHour
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isCurrentHour
                                    ? AppColors.primary
                                    : AppColors.darkOnSurfaceVariant,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 1,
                            height: 10,
                            color: AppColors.darkBorder,
                          ),
                          const Spacer(),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelColumn(BuildContext context, List<Channel> channels) {
    return Container(
      width: _channelColumnWidth,
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        border: Border(
          right: BorderSide(
            color: AppColors.darkBorder,
            width: 0.5,
          ),
        ),
      ),
      child: ListView.builder(
        controller: _channelColumnController,
        itemCount: channels.length,
        itemBuilder: (context, index) {
          final channel = channels[index];
          return _buildChannelRow(context, channel);
        },
      ),
    );
  }

  Widget _buildChannelRow(BuildContext context, Channel channel) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _playChannel(context, channel),
        child: Container(
          height: _rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.darkBorder,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.darkSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: channel.logoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          channel.logoUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.tv_rounded,
                            size: 20,
                            color: AppColors.darkOnSurfaceMuted,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.tv_rounded,
                        size: 20,
                        color: AppColors.darkOnSurfaceMuted,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  channel.displayName,
                  style: TextStyle(
                    color: AppColors.darkOnSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgramGrid(
    BuildContext context,
    List<Channel> channels,
    Map<String, List<Program>> programsByChannel,
    DateTime startTime,
  ) {
    final endTime = startTime.add(Duration(hours: _hoursToShow));

    return ListView.builder(
      controller: _programGridVerticalController,
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        final programs = programsByChannel[channel.tvgId] ??
            programsByChannel[channel.id] ??
            [];

        return Container(
          height: _rowHeight,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.darkBorder,
                width: 0.5,
              ),
            ),
          ),
          child: SingleChildScrollView(
            controller: _programGridController,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: _hourWidth * _hoursToShow,
              child: _buildProgramRow(context, programs, startTime, endTime),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgramRow(
    BuildContext context,
    List<Program> programs,
    DateTime gridStart,
    DateTime gridEnd,
  ) {
    final visiblePrograms = programs
        .where((p) => p.end.isAfter(gridStart) && p.start.isBefore(gridEnd))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    if (visiblePrograms.isEmpty) {
      return Container(
        color: AppColors.epgFutureProgram,
        child: Center(
          child: Text(
            'No program data available',
            style: TextStyle(
              color: AppColors.darkOnSurfaceMuted,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    final widgets = <Widget>[];
    var currentTime = gridStart;

    for (final program in visiblePrograms) {
      if (program.start.isAfter(currentTime)) {
        final gapDuration = program.start.difference(currentTime);
        final gapWidth = _durationToWidth(gapDuration);
        if (gapWidth > 0) {
          widgets.add(_buildGap(gapWidth));
        }
      }

      final displayStart =
          program.start.isBefore(gridStart) ? gridStart : program.start;
      final displayEnd =
          program.end.isAfter(gridEnd) ? gridEnd : program.end;
      final duration = displayEnd.difference(displayStart);
      final cellWidth = _durationToWidth(duration);

      if (cellWidth > 0) {
        widgets.add(_buildProgramCell(context, program, cellWidth));
      }

      currentTime = program.end;
    }

    if (currentTime.isBefore(gridEnd)) {
      final gapDuration = gridEnd.difference(currentTime);
      final gapWidth = _durationToWidth(gapDuration);
      if (gapWidth > 0) {
        widgets.add(_buildGap(gapWidth));
      }
    }

    return Row(children: widgets);
  }

  Widget _buildGap(double width) {
    return Container(
      width: width,
      height: _rowHeight - 2,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: AppColors.epgFutureProgram,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _buildProgramCell(BuildContext context, Program program, double width) {
    final isAiring = program.isCurrentlyAiring;
    final hasEnded = program.hasEnded;
    final timeFormat = DateFormat.jm();

    return Container(
      width: width,
      height: _rowHeight - 2,
      margin: const EdgeInsets.all(1),
      child: Material(
        color: _getCellColor(isAiring, hasEnded),
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showProgramDetails(context, program),
          child: Stack(
            children: [
              // Progress bar for currently airing
              if (isAiring)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: width * program.progress,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.3),
                          AppColors.primary.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        bottomLeft: Radius.circular(6),
                      ),
                    ),
                  ),
                ),
              // Content
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      program.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hasEnded
                            ? AppColors.darkOnSurfaceMuted
                            : isAiring
                                ? AppColors.darkOnSurface
                                : AppColors.darkOnSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${timeFormat.format(program.start)} - ${timeFormat.format(program.end)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.darkOnSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Live badge
              if (program.isLive && isAiring)
                Positioned(
                  top: 6,
                  right: 6,
                  child: _LiveBadge(),
                ),
              // Currently airing indicator
              if (isAiring)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: AppColors.epgNowIndicator,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        bottomLeft: Radius.circular(6),
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

  Color _getCellColor(bool isAiring, bool hasEnded) {
    if (isAiring) return AppColors.epgCurrentProgram.withValues(alpha: 0.15);
    if (hasEnded) return AppColors.epgPastProgram;
    return AppColors.epgFutureProgram;
  }

  double _durationToWidth(Duration duration) {
    return (duration.inMinutes / 60.0) * _hourWidth;
  }

  bool _isCurrentHour(DateTime time) {
    final now = DateTime.now();
    return time.year == now.year &&
        time.month == now.month &&
        time.day == now.day &&
        time.hour == now.hour;
  }

  Future<Map<String, List<Program>>> _getProgramsForChannels(
    String playlistId,
    List<Channel> channels,
    DateTime startTime,
  ) async {
    if (playlistId.isEmpty) return {};

    final endTime = startTime.add(Duration(hours: _hoursToShow));
    final repository = ref.read(epgRepositoryProvider);
    final result =
        await repository.getProgramsInRange(playlistId, startTime, endTime);

    return result.fold(
      (failure) => {},
      (programs) {
        final map = <String, List<Program>>{};
        for (final program in programs) {
          map.putIfAbsent(program.channelId, () => []).add(program);
        }
        return map;
      },
    );
  }

  void _showDatePicker(BuildContext context) async {
    final selectedDate = ref.read(selectedDateProvider);
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now.add(const Duration(days: 7)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.darkSurfaceElevated,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      ref.read(selectedDateProvider.notifier).state = date;
    }
  }

  void _showProgramDetails(BuildContext context, Program program) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.darkSurface.withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.25,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) => SingleChildScrollView(
                controller: scrollController,
                child: ProgramDetailsSheet(
                  program: program,
                  onWatchNow: program.isCurrentlyAiring
                      ? () {
                          Navigator.pop(context);
                          context.push(
                              '${Routes.player}?channelId=${program.channelId}');
                        }
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _playChannel(BuildContext context, Channel channel) {
    context.push('${Routes.player}?channelId=${channel.id}');
  }

  void _refreshEpg(BuildContext context) {
    final playlists = ref.read(playlistNotifierProvider);
    final playlist = playlists.valueOrNull?.firstOrNull;

    if (playlist?.epgUrl != null) {
      ref.read(epgRefreshNotifierProvider.notifier).refreshEpg(
            playlist!.id,
            playlist.epgUrl!,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Refreshing EPG data...'),
          backgroundColor: AppColors.darkSurfaceElevated,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No EPG URL configured'),
          backgroundColor: AppColors.darkSurfaceElevated,
        ),
      );
    }
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
            'Loading TV Guide...',
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
                Icons.calendar_month_rounded,
                size: 48,
                color: AppColors.darkOnSurfaceMuted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No channels available',
              style: TextStyle(
                color: AppColors.darkOnSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a playlist with EPG data to see the TV guide',
              style: TextStyle(
                color: AppColors.darkOnSurfaceVariant,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
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
              'Error loading TV guide',
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
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM TV GUIDE COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

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
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isHovered
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                widget.icon,
                color: _isHovered ? AppColors.primary : AppColors.darkOnSurface,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatefulWidget {
  final DateTime date;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateChip({
    required this.date,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DateChip> createState() => _DateChipState();
}

class _DateChipState extends State<_DateChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppColors.primary
                  : _isHovered
                      ? AppColors.darkSurfaceHover
                      : AppColors.darkSurfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isSelected
                    ? AppColors.primary
                    : _isHovered
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : AppColors.darkBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isSelected
                        ? AppColors.darkBackground
                        : AppColors.darkOnSurface,
                    fontSize: 12,
                    fontWeight:
                        widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.date.day}',
                  style: TextStyle(
                    color: widget.isSelected
                        ? AppColors.darkBackground.withValues(alpha: 0.8)
                        : AppColors.darkOnSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatefulWidget {
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.live,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color:
                    AppColors.live.withValues(alpha: 0.4 * _pulseAnimation.value),
                blurRadius: 6,
              ),
            ],
          ),
          child: Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        );
      },
    );
  }
}
