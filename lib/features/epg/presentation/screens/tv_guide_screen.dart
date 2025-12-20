import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

import '../../../../config/router/routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../playlist/domain/entities/channel.dart';
import '../../../playlist/presentation/providers/playlist_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/entities/program.dart';
import '../../data/compute/epg_compute.dart';
import '../providers/epg_providers.dart';
import '../widgets/program_details_sheet.dart';

/// Provider for the selected group in TV Guide (reads from settings)
final tvGuideSelectedGroupProvider = Provider<String?>((ref) {
  return ref.watch(appSettingsProvider).lastTvGuideCategory;
});

/// Clean TV Guide screen with solid dark design
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
  static const int _hoursPerDay = 24;
  static const int _daysToShow = 7; // Yesterday + Today + 5 days ahead
  static const int _totalHours = _hoursPerDay * _daysToShow;

  // Base date is yesterday at 00:00
  late DateTime _baseDate;

  // Debounce timer for scroll events to reduce rebuilds
  Timer? _scrollDebounceTimer;

  // Cache for processed programs to avoid re-computation on every rebuild
  Future<Map<String, List<Program>>>? _cachedProgramsFuture;
  String? _lastProgramsKey;

  @override
  void initState() {
    super.initState();

    // Set base date to yesterday at midnight
    final now = DateTime.now();
    _baseDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));

    _horizontalControllerGroup = LinkedScrollControllerGroup();
    _timeHeaderController = _horizontalControllerGroup.addAndGet();
    _programGridController = _horizontalControllerGroup.addAndGet();

    _verticalControllerGroup = LinkedScrollControllerGroup();
    _channelColumnController = _verticalControllerGroup.addAndGet();
    _programGridVerticalController = _verticalControllerGroup.addAndGet();

    // Add debounced scroll listener to update selected date as user scrolls
    // Debounce reduces rebuilds during fast scrolling
    _timeHeaderController.addListener(_onHorizontalScrollDebounced);

    _scrollToCurrentTimeWithRetry();

    // Refresh EPG data when TV Guide screen is opened (background thread)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshEpgOnOpen();
    });
  }

  /// Refresh EPG data when TV Guide screen is opened
  /// Runs in background to avoid blocking UI
  void _refreshEpgOnOpen() {
    // Run refresh in background to avoid blocking UI
    // Access ref through the widget's context
    Future.microtask(() async {
      if (!mounted) return;

      try {
        final playlists = ref.read(playlistNotifierProvider);
        final playlist = playlists.valueOrNull?.firstOrNull;

        if (playlist?.epgUrl != null && playlist!.epgUrl!.isNotEmpty) {
          // Refresh EPG in background
          await ref.read(epgRefreshNotifierProvider.notifier).refreshEpg(playlist.id, playlist.epgUrl!);
        }
      } catch (e) {
        // Silently fail - EPG refresh is a background operation
        // User can manually refresh if needed
      }
    });
  }

  void _scrollToCurrentTimeWithRetry({int attempts = 0}) {
    if (attempts >= 10) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_timeHeaderController.hasClients) {
        _scrollToCurrentTime();
      } else {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _scrollToCurrentTimeWithRetry(attempts: attempts + 1);
          }
        });
      }
    });
  }

  /// Process programs using compute isolate - called once per data change
  Future<Map<String, List<Program>>> _processProgramsWithCompute(List<Program> programs, List<Channel> channels, DateTime startTime, DateTime endTime) async {
    if (programs.isEmpty || channels.isEmpty) {
      return <String, List<Program>>{};
    }

    // Use the same logic as programsByChannelProvider but call compute directly
    // This avoids the provider re-evaluation issue
    final useCompute = programs.length > 1000;

    if (kDebugMode) {
      debugPrint('EPG: TV Guide - processing ${programs.length} programs, ${channels.length} channels (useCompute: $useCompute)');
    }

    try {
      if (useCompute) {
        // Import the compute function and use it directly
        final channelsJson = channels.map((c) => channelToJson(c)).toList();
        final programsJson = programs.map((p) {
          return {'id': p.id, 'channelId': p.channelId, 'title': p.title, 'start': p.start.millisecondsSinceEpoch, 'end': p.end.millisecondsSinceEpoch, 'subtitle': p.subtitle, 'description': p.description, 'category': p.category, 'iconUrl': p.iconUrl, 'episodeNum': p.episodeNum, 'rating': p.rating, 'isNew': p.isNew, 'isLive': p.isLive, 'isPremiere': p.isPremiere};
        }).toList();

        final result = await compute(groupProgramsByChannel, GroupProgramsParams(programsJson: programsJson, channelsJson: channelsJson, startTimeMs: startTime.millisecondsSinceEpoch, endTimeMs: endTime.millisecondsSinceEpoch)).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Program grouping timed out');
          },
        );

        // Convert result back to Program objects
        final map = <String, List<Program>>{};
        for (final entry in result.entries) {
          map[entry.key] = entry.value.map((json) {
            return Program(id: json['id'] as String, channelId: json['channelId'] as String, title: json['title'] as String, start: DateTime.fromMillisecondsSinceEpoch(json['start'] as int), end: DateTime.fromMillisecondsSinceEpoch(json['end'] as int), subtitle: json['subtitle'] as String?, description: json['description'] as String?, category: json['category'] as String?, iconUrl: json['iconUrl'] as String?, episodeNum: json['episodeNum'] as String?, rating: json['rating'] as String?, isNew: json['isNew'] as bool? ?? false, isLive: json['isLive'] as bool? ?? false, isPremiere: json['isPremiere'] as bool? ?? false);
          }).toList();
        }

        if (kDebugMode) {
          debugPrint('EPG: TV Guide - completed, ${map.length} channels with programs');
        }

        return map;
      } else {
        // Small dataset - process synchronously
        final map = <String, List<Program>>{};
        final epgIdToChannelId = <String, String>{};

        for (final channel in channels) {
          final epgId = channel.epgId;
          epgIdToChannelId[epgId] = channel.id;
          if (channel.tvgId != null && channel.tvgId != epgId) {
            epgIdToChannelId[channel.tvgId!] = channel.id;
          }
          epgIdToChannelId[channel.id] = channel.id;
        }

        final filteredPrograms = programs.where((p) => p.end.isAfter(startTime) && p.start.isBefore(endTime)).toList();

        for (final program in filteredPrograms) {
          final matchedChannelId = epgIdToChannelId[program.channelId];
          if (matchedChannelId != null) {
            map.putIfAbsent(matchedChannelId, () => []).add(program);
          }
        }

        // Sort programs by start time for each channel
        for (final key in map.keys) {
          map[key]!.sort((a, b) => a.start.compareTo(b.start));
        }

        return map;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EPG: TV Guide - error processing: $e');
      }
      rethrow;
    }
  }

  void _scrollToCurrentTime() {
    // Scroll so that current time is offset to the right (about 1/3 from left edge)
    // This gives better visibility of what's currently playing
    final now = DateTime.now();
    final minutesSinceBase = now.difference(_baseDate).inMinutes;

    if (minutesSinceBase >= 0 && minutesSinceBase < (_totalHours * 60)) {
      // Calculate position for current time, then shift left by ~1 hour width
      // so "now" appears more to the right in the viewport
      final rawOffset = (minutesSinceBase / 60.0) * _hourWidth;
      final offset = rawOffset - _hourWidth; // Shift view back by 1 hour
      if (_timeHeaderController.hasClients) {
        final maxOffset = (_totalHours * _hourWidth) - 400.0;
        _timeHeaderController.animateTo(offset.clamp(0.0, maxOffset), duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    }
  }

  /// Debounced scroll handler to reduce rebuilds during fast scrolling
  void _onHorizontalScrollDebounced() {
    // Cancel existing timer
    _scrollDebounceTimer?.cancel();

    // Set new timer - only update state after scrolling stops for 150ms
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted || !_timeHeaderController.hasClients) return;

      // Calculate which day is currently visible at the center of the screen
      final offset = _timeHeaderController.offset;
      final minutesSinceBase = ((offset + 200) / _hourWidth) * 60; // +200 for ~center of screen
      final dateFromScroll = _baseDate.add(Duration(minutes: minutesSinceBase.toInt()));
      final dayDate = DateTime(dateFromScroll.year, dateFromScroll.month, dateFromScroll.day);

      // Update the selectedDateProvider if it changed
      final currentSelected = ref.read(selectedDateProvider);
      if (dayDate.year != currentSelected.year || dayDate.month != currentSelected.month || dayDate.day != currentSelected.day) {
        ref.read(selectedDateProvider.notifier).state = dayDate;
      }
    });
  }

  @override
  void dispose() {
    _scrollDebounceTimer?.cancel();
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
    final selectedGroup = ref.watch(tvGuideSelectedGroupProvider);
    final groupsAsync = ref.watch(channelGroupsProvider);
    // Use baseDate for the full multi-day grid starting from yesterday
    final startTime = _baseDate;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          _buildHeader(context, groupsAsync, selectedGroup, selectedDate),
          // Main content
          Expanded(
            child: channelsAsync.when(
              data: (channels) {
                if (channels.isEmpty) {
                  return _buildEmptyState(context);
                }
                final filteredChannels = selectedGroup == null ? channels : channels.where((c) => c.group?.toLowerCase() == selectedGroup.toLowerCase()).toList();
                if (filteredChannels.isEmpty) {
                  return _buildEmptyState(context, message: 'No channels in this category');
                }
                return _buildTvGuide(context, filteredChannels, startTime);
              },
              loading: () => _buildLoadingState(),
              error: (error, _) => _buildErrorState(context, error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AsyncValue<List<String>> groupsAsync, String? selectedGroup, DateTime selectedDate) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Text(
                    'TV Guide',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _buildCategoryDropdown(context, groupsAsync, selectedGroup)),
                  _IconButton(icon: Icons.today_rounded, onTap: () => _showDatePicker(context), tooltip: 'Select date'),
                  _IconButton(icon: Icons.my_location_rounded, onTap: _scrollToCurrentTime, tooltip: 'Go to now'),
                  _IconButton(icon: Icons.refresh_rounded, onTap: () => _refreshEpg(context), tooltip: 'Refresh EPG'),
                ],
              ),
            ),
            // Date selector
            _buildDateSelector(context, selectedDate),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(BuildContext context, AsyncValue<List<String>> groupsAsync, String? selectedGroup) {
    return groupsAsync.when(
      data: (groups) {
        if (groups.isEmpty) return const SizedBox.shrink();

        return Container(
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: selectedGroup,
              isExpanded: true,
              isDense: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 20),
              dropdownColor: AppColors.surface,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
              hint: Text(
                'All Channels',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Channels', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                ),
                ...groups.map(
                  (group) => DropdownMenuItem<String?>(
                    value: group,
                    child: Text(
                      group,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                ref.read(appSettingsProvider.notifier).setLastTvGuideCategory(value);
              },
            ),
          ),
        );
      },
      loading: () => SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary))),
      error: (_, __) => const SizedBox.shrink(),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = date.year == selectedDate.year && date.month == selectedDate.month && date.day == selectedDate.day;
          final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;

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

  Widget _buildTvGuide(BuildContext context, List<Channel> channels, DateTime startTime) {
    final playlists = ref.watch(playlistNotifierProvider);
    final playlistId = playlists.valueOrNull?.firstOrNull?.id ?? '';

    // Early return if no playlist
    if (playlistId.isEmpty) {
      return Column(
        children: [
          _buildTimeHeader(context, startTime),
          Expanded(
            child: Row(
              children: [
                _buildChannelColumn(context, channels),
                Expanded(
                  child: Center(
                    child: Text(
                      'No playlist selected. Please add a playlist with EPG data.',
                      style: TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Use FutureProvider instead of FutureBuilder to cache and avoid rebuilds
    final endTime = startTime.add(Duration(hours: _totalHours));
    final programsAsync = ref.watch(programsInRangeProvider((playlistId: playlistId, start: startTime, end: endTime)));

    return programsAsync.when(
      data: (programs) {
        // Show empty state if no programs
        if (programs.isEmpty) {
          return Column(
            children: [
              _buildTimeHeader(context, startTime),
              Expanded(
                child: Row(
                  children: [
                    _buildChannelColumn(context, channels),
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.tv_off_rounded, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 16),
                            Text(
                              'No EPG data available',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Text('Refresh EPG data to load program guide', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        // Process programs directly using compute isolate to avoid provider re-evaluation issues
        // Create stable DateTime instances
        final stableStartTime = DateTime(startTime.year, startTime.month, startTime.day, startTime.hour);
        final stableEndTime = DateTime(endTime.year, endTime.month, endTime.day, endTime.hour);

        // Create a stable key based on data to cache the future
        final programsKey = '${programs.length}_${channels.length}_${programs.firstOrNull?.id ?? ''}_${channels.firstOrNull?.id ?? ''}_${stableStartTime.millisecondsSinceEpoch}_${stableEndTime.millisecondsSinceEpoch}';

        // Only create a new future if the data has changed
        if (_cachedProgramsFuture == null || _lastProgramsKey != programsKey) {
          if (kDebugMode) {
            debugPrint('EPG: TV Guide - creating new processing future (key: $programsKey)');
          }
          _cachedProgramsFuture = _processProgramsWithCompute(programs, channels, stableStartTime, stableEndTime);
          _lastProgramsKey = programsKey;
        }

        // Use FutureBuilder with cached future to process data once
        return FutureBuilder<Map<String, List<Program>>>(
          future: _cachedProgramsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              if (kDebugMode) {
                debugPrint('EPG: TV Guide - processing programs in isolate...');
              }
              return Column(
                children: [
                  _buildTimeHeader(context, startTime),
                  Expanded(
                    child: Row(
                      children: [
                        _buildChannelColumn(context, channels),
                        const Expanded(child: Center(child: CircularProgressIndicator())),
                      ],
                    ),
                  ),
                ],
              );
            }

            if (snapshot.hasError) {
              if (kDebugMode) {
                debugPrint('EPG: TV Guide - error: ${snapshot.error}');
              }
              return Column(
                children: [
                  _buildTimeHeader(context, startTime),
                  Expanded(
                    child: Row(
                      children: [
                        _buildChannelColumn(context, channels),
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, color: AppColors.textMuted, size: 48),
                                const SizedBox(height: 16),
                                Text('Error processing programs', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                                const SizedBox(height: 8),
                                Text('${snapshot.error}', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final programsByChannel = snapshot.data ?? {};
            if (kDebugMode) {
              debugPrint('EPG: TV Guide - displaying ${programsByChannel.length} channels with programs');
            }

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
                      Expanded(child: _buildProgramGrid(context, channels, programsByChannel, startTime)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
      loading: () => Column(
        children: [
          _buildTimeHeader(context, startTime),
          Expanded(
            child: Row(
              children: [
                _buildChannelColumn(context, channels),
                const Expanded(child: Center(child: CircularProgressIndicator())),
              ],
            ),
          ),
        ],
      ),
      error: (error, _) => Column(
        children: [
          _buildTimeHeader(context, startTime),
          Expanded(
            child: Row(
              children: [
                _buildChannelColumn(context, channels),
                Expanded(child: Center(child: Text('Error loading programs: $error'))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeHeader(BuildContext context, DateTime startTime) {
    final timeFormat = DateFormat.j();
    final dateFormat = DateFormat.MMMd();
    final totalWidth = _hourWidth * _totalHours;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Channel column header
          Container(
            width: _channelColumnWidth,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.live_tv_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Channels',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          // Time slots - with date markers at midnight
          Expanded(
            child: SingleChildScrollView(
              controller: _timeHeaderController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: totalWidth,
                // Use ListView.builder instead of Row with List.generate for better performance
                // This creates widgets lazily and only renders visible items
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _totalHours,
                  itemBuilder: (context, index) {
                    final time = startTime.add(Duration(hours: index));
                    final isCurrentHour = _isCurrentHour(time);
                    final isMidnight = time.hour == 0;
                    final now = DateTime.now();
                    final isToday = time.year == now.year && time.month == now.month && time.day == now.day;

                    return Container(
                      width: _hourWidth,
                      decoration: BoxDecoration(
                        color: isCurrentHour ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                        border: Border(
                          right: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
                          // Add a stronger left border at midnight to indicate day change
                          left: isMidnight ? BorderSide(color: AppColors.primary.withValues(alpha: 0.5), width: 2) : BorderSide.none,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Show date at midnight
                              if (isMidnight)
                                Text(
                                  isToday ? 'Today' : dateFormat.format(time),
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                                ),
                              Text(
                                timeFormat.format(time),
                                style: TextStyle(fontSize: 13, fontWeight: isCurrentHour ? FontWeight.w700 : FontWeight.w500, color: isCurrentHour ? AppColors.primary : AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
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
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: ListView.builder(
        controller: _channelColumnController,
        itemCount: channels.length,
        // Add itemExtent for better ListView performance (fixed height rows)
        itemExtent: _rowHeight,
        itemBuilder: (context, index) {
          final channel = channels[index];
          return _ChannelTile(channel: channel, height: _rowHeight, onTap: () => _playChannel(context, channel));
        },
      ),
    );
  }

  Widget _buildProgramGrid(BuildContext context, List<Channel> channels, Map<String, List<Program>> programsByChannel, DateTime startTime) {
    final endTime = startTime.add(Duration(hours: _totalHours));
    final totalWidth = _hourWidth * _totalHours;

    // Standard TV guide - no distracting vertical line
    // Programs clip naturally and text aligns left for readability
    return SingleChildScrollView(
      controller: _programGridController,
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: SizedBox(
        width: totalWidth,
        child: ListView.builder(
          controller: _programGridVerticalController,
          itemCount: channels.length,
          // Add itemExtent for better ListView performance (fixed height rows)
          itemExtent: _rowHeight,
          itemBuilder: (context, index) {
            final channel = channels[index];
            // Look up programs by channel.id (which is what we use as the map key)
            // The processing function matches programs by tvgId but stores them under channel.id
            final programs = programsByChannel[channel.id] ?? [];

            // Wrap each row in RepaintBoundary to isolate repaints and improve performance
            // This prevents repainting other rows when scrolling
            return RepaintBoundary(
              child: Container(
                height: _rowHeight,
                width: totalWidth,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
                ),
                child: _buildProgramRow(context, channel, programs, startTime, endTime),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgramRow(BuildContext context, Channel channel, List<Program> programs, DateTime gridStart, DateTime gridEnd) {
    // Programs should already be filtered and sorted from isolate processing
    // But filter again for safety (this is fast since list is already sorted)
    final visiblePrograms = <Program>[];
    for (final program in programs) {
      if (program.end.isAfter(gridStart) && program.start.isBefore(gridEnd)) {
        visiblePrograms.add(program);
      }
      // Early exit if we've passed the grid end (programs are sorted)
      if (program.start.isAfter(gridEnd)) break;
    }

    if (visiblePrograms.isEmpty) {
      return Container(
        color: AppColors.surfaceElevated.withValues(alpha: 0.3),
        child: Center(
          child: Text('No program data', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ),
      );
    }

    final widgets = <Widget>[];
    var currentTime = gridStart;
    var currentPosition = 0.0; // Track cumulative position in pixels

    for (final program in visiblePrograms) {
      if (program.start.isAfter(currentTime)) {
        final gapDuration = program.start.difference(currentTime);
        final gapWidth = _durationToWidth(gapDuration);
        if (gapWidth > 0) {
          widgets.add(_buildGap(gapWidth));
          currentPosition += gapWidth;
        }
      }

      final displayStart = program.start.isBefore(gridStart) ? gridStart : program.start;
      final displayEnd = program.end.isAfter(gridEnd) ? gridEnd : program.end;
      final duration = displayEnd.difference(displayStart);
      final cellWidth = _durationToWidth(duration);

      // Calculate how much of the program extends left of the visible grid
      final hiddenLeftWidth = program.start.isBefore(gridStart) ? _durationToWidth(gridStart.difference(program.start)) : 0.0;

      if (cellWidth > 0) {
        widgets.add(_ProgramCell(program: program, width: cellWidth, height: _rowHeight, onTap: () => _showProgramDetails(context, program, channel), programStartOffset: currentPosition, hiddenLeftWidth: hiddenLeftWidth, scrollController: _programGridController));
        currentPosition += cellWidth;
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
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
        ),
      ),
    );
  }

  double _durationToWidth(Duration duration) {
    return (duration.inMinutes / 60.0) * _hourWidth;
  }

  bool _isCurrentHour(DateTime time) {
    final now = DateTime.now();
    return time.year == now.year && time.month == now.month && time.day == now.day && time.hour == now.hour;
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
            colorScheme: ColorScheme.dark(primary: AppColors.primary, surface: AppColors.surface),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      ref.read(selectedDateProvider.notifier).state = date;
    }
  }

  void _showProgramDetails(BuildContext context, Program program, Channel channel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                      context.push(Routes.playerPath(channel.id));
                    }
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  void _playChannel(BuildContext context, Channel channel) {
    context.push(Routes.playerPath(channel.id));
  }

  void _refreshEpg(BuildContext context) {
    final playlists = ref.read(playlistNotifierProvider);
    final playlist = playlists.valueOrNull?.firstOrNull;

    if (playlist?.epgUrl != null) {
      ref.read(epgRefreshNotifierProvider.notifier).refreshEpg(playlist!.id, playlist.epgUrl!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary))),
              const SizedBox(width: 12),
              const Text('Refreshing EPG data...'),
            ],
          ),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No EPG URL configured'),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary))),
          const SizedBox(height: 24),
          Text(
            'Loading TV Guide...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {String? message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.surfaceElevated, shape: BoxShape.circle),
                child: Icon(Icons.calendar_month_rounded, size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text(
                message ?? 'No channels available',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                message != null ? 'Select a different category to see channels' : 'Add a playlist with EPG data to see the TV guide',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              ),
              const SizedBox(height: 24),
              Text(
                'Error loading TV guide',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _refreshEpg(context),
                icon: Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
// TV GUIDE COMPONENTS - Clean Solid Design
// ═══════════════════════════════════════════════════════════════════════════

class _IconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _IconButton({required this.icon, required this.onTap, this.tooltip});

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip ?? '',
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(color: _isHovered ? AppColors.surfaceHover : Colors.transparent, borderRadius: BorderRadius.circular(8)),
            child: Icon(widget.icon, color: _isHovered ? AppColors.primary : AppColors.textSecondary, size: 22),
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

  const _DateChip({required this.date, required this.label, required this.isSelected, required this.onTap});

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
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.primary
                : _isHovered
                ? AppColors.surfaceHover
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.isSelected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(color: widget.isSelected ? Colors.black : AppColors.textPrimary, fontSize: 13, fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500),
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.date.day}',
                style: TextStyle(color: widget.isSelected ? Colors.black.withValues(alpha: 0.7) : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelTile extends StatefulWidget {
  final Channel channel;
  final double height;
  final VoidCallback onTap;

  const _ChannelTile({required this.channel, required this.height, required this.onTap});

  @override
  State<_ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<_ChannelTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : Colors.transparent,
            border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
          ),
          child: Row(
            children: [
              // Channel logo
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _isHovered ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border),
                ),
                child: widget.channel.logoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.network(
                          widget.channel.logoUrl!,
                          fit: BoxFit.contain,
                          // Add caching and error handling for better performance on Android
                          cacheWidth: 40, // Limit image size for memory efficiency
                          cacheHeight: 40,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Icon(Icons.tv_rounded, size: 18, color: AppColors.textMuted),
                        ),
                      )
                    : Icon(Icons.tv_rounded, size: 18, color: AppColors.textMuted),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.channel.displayName,
                  style: TextStyle(color: _isHovered ? AppColors.primary : AppColors.textPrimary, fontSize: 12, fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500),
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
}

class _ProgramCell extends StatefulWidget {
  final Program program;
  final double width;
  final double height;
  final VoidCallback onTap;
  final double programStartOffset; // Cell's position in grid (pixels)
  final double hiddenLeftWidth; // How much extends left of grid start
  final ScrollController? scrollController;

  const _ProgramCell({required this.program, required this.width, required this.height, required this.onTap, this.programStartOffset = 0, this.hiddenLeftWidth = 0, this.scrollController});

  @override
  State<_ProgramCell> createState() => _ProgramCellState();
}

class _ProgramCellState extends State<_ProgramCell> {
  bool _isHovered = false;
  double _lastCalculatedOffset = 0.0;

  // Cache DateFormat to avoid recreating on every build
  static final DateFormat _timeFormat = DateFormat.jm();

  // Threshold for offset changes to trigger rebuild (pixels)
  static const double _offsetThreshold = 8.0;

  /// Calculate how much to offset the text based on current scroll position
  /// For currently airing programs, aligns text to current time position
  /// Uses threshold to avoid excessive rebuilds - only returns new value when
  /// change is significant enough to warrant a repaint
  double _calculateTextOffset(double scrollOffset) {
    const double minCellWidthForOffset = 80.0;
    const double minVisibleTextSpace = 60.0;
    const double textPadding = 10.0;

    // Don't offset for very narrow cells
    if (widget.width < minCellWidthForOffset) return _lastCalculatedOffset;

    final isAiring = widget.program.isCurrentlyAiring;
    final viewportLeftEdge = scrollOffset;
    final cellLeftEdge = widget.programStartOffset;

    // For currently airing programs, align text to current time position (where progress indicator is)
    // This ensures text is always visible at "now" even if program extends far to the left
    if (isAiring && widget.program.progress > 0) {
      // Calculate where the current time is within the visible cell
      // progress is 0.0 to 1.0, representing position through the entire program
      // We need to find where that position is in the visible cell
      final currentTimePositionInCell = widget.width * widget.program.progress;
      final currentTimePositionInGrid = cellLeftEdge + currentTimePositionInCell;

      // If current time position is to the left of viewport, offset text to align with it
      if (currentTimePositionInGrid < viewportLeftEdge) {
        // Calculate offset needed to align text to current time position
        // We want the text to start at the current time position
        var textOffset = viewportLeftEdge - currentTimePositionInGrid;

        // But don't offset so much that text has less than minVisibleTextSpace
        final maxOffset = widget.width - minVisibleTextSpace - (textPadding * 2);
        final newOffset = textOffset.clamp(0.0, maxOffset.clamp(0.0, double.infinity));

        // Only update if change exceeds threshold
        if ((newOffset - _lastCalculatedOffset).abs() >= _offsetThreshold) {
          _lastCalculatedOffset = newOffset;
        }
        return _lastCalculatedOffset;
      }

      // If current time position is within or to the right of viewport,
      // check if we need to offset to keep text visible
      if (currentTimePositionInGrid >= viewportLeftEdge && currentTimePositionInGrid <= viewportLeftEdge + 200) {
        // Current time is near viewport edge, ensure text is visible
        // If cell extends left of viewport, offset text to viewport edge
        if (cellLeftEdge < viewportLeftEdge) {
          var textOffset = viewportLeftEdge - cellLeftEdge;
          final maxOffset = widget.width - minVisibleTextSpace - (textPadding * 2);
          final newOffset = textOffset.clamp(0.0, maxOffset.clamp(0.0, double.infinity));

          if ((newOffset - _lastCalculatedOffset).abs() >= _offsetThreshold) {
            _lastCalculatedOffset = newOffset;
          }
          return _lastCalculatedOffset;
        }
      }

      // If current time is well within viewport, no offset needed
      if (_lastCalculatedOffset != 0.0) {
        _lastCalculatedOffset = 0.0;
      }
      return 0.0;
    }

    // For non-airing programs, use original viewport edge alignment
    // If cell left edge is still in or ahead of viewport, no offset needed
    if (cellLeftEdge >= viewportLeftEdge) {
      if (_lastCalculatedOffset != 0.0) {
        _lastCalculatedOffset = 0.0;
      }
      return 0.0;
    }

    // Calculate ideal offset: push text right to viewport edge
    var textOffset = viewportLeftEdge - cellLeftEdge;

    // But don't offset so much that text has less than minVisibleTextSpace
    final maxOffset = widget.width - minVisibleTextSpace - (textPadding * 2);

    // Clamp to valid range
    final newOffset = textOffset.clamp(0.0, maxOffset.clamp(0.0, double.infinity));

    // Only update if change exceeds threshold (reduces unnecessary repaints)
    if ((newOffset - _lastCalculatedOffset).abs() >= _offsetThreshold) {
      _lastCalculatedOffset = newOffset;
    }

    return _lastCalculatedOffset;
  }

  @override
  Widget build(BuildContext context) {
    final isAiring = widget.program.isCurrentlyAiring;
    final hasEnded = widget.program.hasEnded;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: widget.width,
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: _getCellColor(isAiring, hasEnded, _isHovered),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isAiring
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : _isHovered
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            child: Stack(
              children: [
                // Progress bar for currently airing
                if (isAiring)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: widget.width * widget.program.progress,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(7), bottomLeft: Radius.circular(7)),
                      ),
                    ),
                  ),
                // Content with sticky text offset for long programs
                _buildOffsetContent(isAiring, hasEnded),
                // Live badge
                if (widget.program.isLive && isAiring)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.live, borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            'LIVE',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
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
                        color: AppColors.primary,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build the content with scroll-aware text offset for long programs
  Widget _buildOffsetContent(bool isAiring, bool hasEnded) {
    // Use cached static DateFormat for performance
    final startTime = _timeFormat.format(widget.program.start);
    final endTime = _timeFormat.format(widget.program.end);

    // Build the text content widget - use dynamic left padding instead of Transform
    // to ensure text has full remaining width available
    Widget buildTextContent(double offset) {
      return Padding(
        padding: EdgeInsets.only(left: 10 + offset, right: 10, top: 10, bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.program.title,
              style: TextStyle(
                color: hasEnded
                    ? AppColors.textMuted
                    : isAiring
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: isAiring ? FontWeight.w600 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '$startTime - $endTime',
              style: TextStyle(color: hasEnded ? AppColors.textMuted.withValues(alpha: 0.7) : AppColors.textMuted, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    // CRITICAL: Disable ListenableBuilder on Android to prevent performance issues
    // The scroll listener on every cell causes excessive rebuilds and freezes
    // Only use sticky text on desktop platforms where it's beneficial
    if (widget.scrollController != null && widget.width > 200 && (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux)) {
      // Only enable on desktop platforms - disabled on Android/iOS for performance
      return RepaintBoundary(
        child: ListenableBuilder(
          listenable: widget.scrollController!,
          builder: (context, _) {
            final offset = _calculateTextOffset(widget.scrollController!.offset);
            return buildTextContent(offset);
          },
        ),
      );
    }

    // Otherwise, render without offset (narrow cells don't need sticky text)
    // This is the default on Android/iOS to prevent performance issues
    return buildTextContent(0);
  }

  Color _getCellColor(bool isAiring, bool hasEnded, bool isHovered) {
    if (isAiring) {
      return isHovered ? AppColors.surfaceElevated : AppColors.surface;
    }
    if (hasEnded) {
      return AppColors.surfaceElevated.withValues(alpha: 0.3);
    }
    return isHovered ? AppColors.surfaceHover : AppColors.surfaceElevated.withValues(alpha: 0.5);
  }
}
