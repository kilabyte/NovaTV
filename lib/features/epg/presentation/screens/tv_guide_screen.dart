import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
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
import '../../data/compute/epg_compute.dart';
import '../../domain/entities/program.dart';
import '../providers/epg_providers.dart';
import '../widgets/program_details_sheet.dart';
import '../../../../shared/widgets/tv_focusable.dart';

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
  static const int _daysToShow = 7; // Today + 6 days ahead
  static const int _totalHours = _hoursPerDay * _daysToShow;

  // Base date is today at 00:00; the grid and date chips extend forward from
  // here so users never see yesterday in the chip row.
  late DateTime _baseDate;

  // Debounce timer for scroll events to reduce rebuilds
  Timer? _scrollDebounceTimer;

  // Cache for processed programs to avoid re-computation on every rebuild
  Future<Map<String, List<Program>>>? _cachedProgramsFuture;
  String? _lastProgramsKey;

  // Current scroll offset for sticky text alignment (works on all platforms).
  // A ValueNotifier instead of setState: only the time header and the program
  // rows listen, so a horizontal fling no longer rebuilds the whole screen
  // (header chrome, date chips, channel column) on every frame.
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();

    // Base date = today at 00:00. The grid and date-chip strip both start
    // here so users never see yesterday.
    final now = DateTime.now();
    _baseDate = DateTime(now.year, now.month, now.day);

    _horizontalControllerGroup = LinkedScrollControllerGroup();
    _timeHeaderController = _horizontalControllerGroup.addAndGet();
    _programGridController = _horizontalControllerGroup.addAndGet();

    _verticalControllerGroup = LinkedScrollControllerGroup();
    _channelColumnController = _verticalControllerGroup.addAndGet();
    _programGridVerticalController = _verticalControllerGroup.addAndGet();

    // Add debounced scroll listener to update selected date as user scrolls
    // Debounce reduces rebuilds during fast scrolling
    _timeHeaderController.addListener(_onHorizontalScrollDebounced);

    // Add scroll listener for sticky text offset (works on all platforms)
    _programGridController.addListener(_onScrollOffsetChanged);

    _scrollToCurrentTimeWithRetry();

    // Refresh EPG data when TV Guide screen is opened (background thread)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshEpgOnOpen();
    });
  }

  /// Refresh EPG data when TV Guide screen is opened, but only if the cached
  /// data is actually stale. Otherwise we'd double-refresh right after the
  /// startup auto-refresh ran. Iterates every playlist — previously only the
  /// first playlist's EPG was refreshed.
  void _refreshEpgOnOpen() {
    Future.microtask(() async {
      if (!mounted) return;

      try {
        final playlists = ref.read(playlistNotifierProvider).valueOrNull ?? const [];
        for (final playlist in playlists) {
          if (!mounted) return;
          if (playlist.epgUrl == null || playlist.epgUrl!.isEmpty) continue;
          // The provider is a non-autoDispose family, so its first answer is
          // cached for the app's lifetime; invalidate so validity (a 24h
          // fetchedAt check) is re-evaluated on every guide open.
          ref.invalidate(hasValidEpgDataProvider(playlist.id));
          final hasValid = await ref.read(hasValidEpgDataProvider(playlist.id).future);
          if (hasValid) continue;
          await ref.read(epgRefreshNotifierProvider.notifier).refreshEpg(playlist.id, playlist.epgUrl!);
        }
      } catch (_) {
        // Background operation; user can manually refresh.
      }
    });
  }

  /// Timer used when the scroll controllers aren't attached yet; cancelled in
  /// dispose() so late fires can't touch disposed state.
  Timer? _scrollToNowRetryTimer;

  void _scrollToCurrentTimeWithRetry({int attempts = 0}) {
    // 50 attempts × 100ms = 5s grace period for the channel list +
    // controllers to attach. Cold starts on slow disks were timing out
    // at the previous 10-attempt cap (1s) and never scrolling to now.
    if (attempts >= 50) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_timeHeaderController.hasClients) {
        _scrollToCurrentTime();
        return;
      }

      _scrollToNowRetryTimer?.cancel();
      _scrollToNowRetryTimer = Timer(const Duration(milliseconds: 100), () {
        if (mounted) {
          _scrollToCurrentTimeWithRetry(attempts: attempts + 1);
        }
      });
    });
  }

  /// Process programs using compute isolate - called once per data change.
  /// Program/Channel entities are plain immutable objects, so they cross the
  /// isolate boundary directly; the previous implementation built a JSON map
  /// for every program and re-parsed the result on the main isolate, paying
  /// two full dataset copies right when the guide opened.
  Future<Map<String, List<Program>>> _processProgramsWithCompute(List<Program> programs, List<Channel> channels, DateTime startTime, DateTime endTime) async {
    if (programs.isEmpty || channels.isEmpty) {
      return <String, List<Program>>{};
    }

    final useCompute = programs.length > 1000;

    if (kDebugMode) {
      debugPrint('EPG: TV Guide - processing ${programs.length} programs, ${channels.length} channels (useCompute: $useCompute)');
    }

    final args = GuideGroupArgs(programs: programs, channels: channels, startTime: startTime, endTime: endTime);

    try {
      if (useCompute) {
        return await compute(groupProgramsForGuide, args).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Program grouping timed out');
          },
        );
      }
      // Small dataset - process synchronously
      return groupProgramsForGuide(args);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EPG: TV Guide - error processing: $e');
      }
      rethrow;
    }
  }

  /// Jump the grid's horizontal viewport to the start of [date].
  void _scrollToDate(DateTime date) {
    if (!_timeHeaderController.hasClients) return;
    final target = DateTime(date.year, date.month, date.day);
    final minutesSinceBase = target.difference(_baseDate).inMinutes;
    if (minutesSinceBase < 0) return;
    final offset = (minutesSinceBase / 60.0) * _hourWidth;
    final maxOffset = (_totalHours * _hourWidth) - 400.0;
    _timeHeaderController.animateTo(
      offset.clamp(0.0, maxOffset),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
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

  /// Scroll offset listener for sticky text alignment on all platforms.
  /// Updates the ValueNotifier only; ValueListenableBuilders on the time
  /// header and program rows rebuild, nothing else does.
  void _onScrollOffsetChanged() {
    if (!mounted || !_programGridController.hasClients) return;
    _scrollOffset.value = _programGridController.offset;
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
    _scrollToNowRetryTimer?.cancel();
    _scrollOffset.dispose();
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
    // Rebuild once per minute so the airing highlight, progress fills, LIVE
    // badges, and current-hour header keep advancing while the guide sits
    // idle (typical on a TV). Without this the indicators freeze at the
    // last interaction.
    ref.watch(minuteTickProvider);
    // Use baseDate for the full multi-day grid starting from yesterday
    final startTime = _baseDate;

    // Roll _baseDate forward when the day changes so a guide left open past
    // midnight doesn't show yesterday as the first chip or lose a day of
    // lookahead from its fetch window.
    ref.listen<AsyncValue<DateTime>>(minuteTickProvider, (previous, next) {
      final now = next.valueOrNull ?? DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (today != _baseDate) {
        setState(() {
          _baseDate = today;
          _cachedProgramsFuture = null;
          _lastProgramsKey = null;
        });
        _scrollToCurrentTimeWithRetry();
      }
    });

    // Listen to goToNowTrigger to scroll to current time when triggered
    // This handles: navigation to Guide tab, EPG refresh, playlist refresh
    ref.listen<int>(goToNowTriggerProvider, (previous, next) {
      if (previous != null && next != previous) {
        _scrollToCurrentTimeWithRetry();
      }
    });

    // Listen to EPG refresh state - when a refresh batch completes, the
    // cached programs provider is now stale. Invalidate it so the grid
    // re-fetches and the data actually shows up without the user having to
    // navigate away and back. Also drop the locally cached grouping future:
    // its length/first-id key can't detect content-only EPG updates. Runs on
    // error completions too, since a partially failed batch may still have
    // refreshed other playlists.
    ref.listen<AsyncValue<void>>(epgRefreshNotifierProvider, (previous, next) {
      if (previous?.isLoading == true && !next.isLoading) {
        _cachedProgramsFuture = null;
        _lastProgramsKey = null;
        ref.invalidate(programsInRangeAllPlaylistsProvider);
        _scrollToCurrentTimeWithRetry();
      }
    });

    // Re-scroll to now once the program data finishes loading on the
    // initial view. Without this, the scroll-retry chain in initState can
    // expire before the provider resolves on a cold start, and we end up
    // pinned at the left edge of the grid (today 00:00) instead of "now".
    ref.listen<AsyncValue<List<Program>>>(
      programsInRangeAllPlaylistsProvider((start: _baseDate, end: _baseDate.add(Duration(hours: _totalHours)))),
      (previous, next) {
        final wasNotReady = previous == null || previous.isLoading || (previous.valueOrNull?.isEmpty ?? true);
        final nowReady = next.hasValue && (next.value?.isNotEmpty ?? false);
        if (wasNotReady && nowReady) {
          _scrollToCurrentTimeWithRetry();
        }
      },
    );

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
    final dates = List.generate(_daysToShow, (i) {
      return _baseDate.add(Duration(days: i));
    });

    return SizedBox(
      // 48 leaves real slack for the chips (36px content + border); at 44
      // they fit with zero margin and Android's font metrics clipped the
      // bottom edge.
      height: 48,
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
                _scrollToDate(date);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTvGuide(BuildContext context, List<Channel> channels, DateTime startTime) {
    final playlists = ref.watch(playlistNotifierProvider).valueOrNull ?? const [];

    // Early return if no playlists at all
    if (playlists.isEmpty) {
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

    // Merge EPG from every playlist so multi-playlist users see all programs.
    final endTime = startTime.add(Duration(hours: _totalHours));
    final programsAsync = ref.watch(programsInRangeAllPlaylistsProvider((start: startTime, end: endTime)));

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
          // PERFORMANCE: Only build visible hour markers based on scroll offset
          Expanded(
            child: SingleChildScrollView(
              controller: _timeHeaderController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: totalWidth,
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrollOffset,
                  builder: (context, offset, _) => Row(children: _buildTimeHeaderItems(startTime, dateFormat, timeFormat, offset)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build time header items with viewport optimization
  /// Only renders full content for visible items, uses lightweight placeholders for others
  List<Widget> _buildTimeHeaderItems(DateTime startTime, DateFormat dateFormat, DateFormat timeFormat, double scrollOffset) {
    final screenWidth = MediaQuery.of(context).size.width - _channelColumnWidth;
    final viewportBuffer = screenWidth; // Buffer for smooth scrolling
    final viewportStart = scrollOffset - viewportBuffer;
    final viewportEnd = scrollOffset + screenWidth + viewportBuffer;

    final now = DateTime.now();

    return List.generate(_totalHours, (index) {
      final itemStart = index * _hourWidth;
      final itemEnd = itemStart + _hourWidth;

      // Only build full content for visible items
      if (itemEnd >= viewportStart && itemStart <= viewportEnd) {
        final time = startTime.add(Duration(hours: index));
        final isCurrentHour = _isCurrentHour(time);
        final isMidnight = time.hour == 0;
        final isToday = time.year == now.year && time.month == now.month && time.day == now.day;

        return Container(
          width: _hourWidth,
          decoration: BoxDecoration(
            color: isCurrentHour ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
            border: Border(
              right: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
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
      }

      // Lightweight placeholder for non-visible items
      return SizedBox(width: _hourWidth);
    });
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
        // Performance optimizations
        itemExtent: _rowHeight, // Fixed height for faster layout
        cacheExtent: _rowHeight * 5, // Preload 5 rows for smoother scrolling
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
          // Performance optimizations for large lists
          itemExtent: _rowHeight, // Fixed height rows for faster layout
          cacheExtent: _rowHeight * 5, // Preload 5 rows for smoother scrolling
          addAutomaticKeepAlives: false, // Disable keep-alive to reduce memory
          addRepaintBoundaries: false, // We add our own RepaintBoundary
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
                // Listen to the scroll offset per row so horizontal scrolling
                // rebuilds only the visible rows (viewport culling + sticky
                // text), not the whole screen.
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrollOffset,
                  builder: (context, offset, _) => _buildProgramRow(context, channel, programs, startTime, endTime, offset),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgramRow(BuildContext context, Channel channel, List<Program> programs, DateTime gridStart, DateTime gridEnd, double scrollOffset) {
    // PERFORMANCE: Use Stack + Positioned so off-viewport cells are omitted
    // from the widget tree entirely instead of held as SizedBox placeholders.
    // For a 7-day/N-channel guide this drops a row's widget count from ~350
    // to ~8 (just the visible window + gaps).
    final screenWidth = MediaQuery.of(context).size.width - _channelColumnWidth;
    final viewportBuffer = screenWidth;
    final viewportStart = scrollOffset - viewportBuffer;
    final viewportEnd = scrollOffset + screenWidth + viewportBuffer;
    final totalWidth = _totalHours * _hourWidth;

    // The grouping step already filtered to programs overlapping the grid
    // window and sorted them, so no per-rebuild rescan/copy is needed here.
    final visiblePrograms = programs;

    if (visiblePrograms.isEmpty) {
      return Container(
        width: totalWidth,
        color: AppColors.surfaceElevated.withValues(alpha: 0.3),
        child: Center(
          child: Text('No program data', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ),
      );
    }

    final children = <Widget>[];
    var lastEnd = gridStart;

    void addIfVisible(double left, double width, Widget Function() builder, {Key? key}) {
      final right = left + width;
      if (right < viewportStart || left > viewportEnd) return;
      children.add(Positioned(
        key: key,
        left: left,
        top: 0,
        width: width,
        height: _rowHeight,
        child: builder(),
      ));
    }

    // Absolute-position each program at its actual start time. This is
    // robust to overlapping / out-of-order EPG: the previous sequential
    // accumulator would drift rightward whenever a later program started
    // before the previous one ended.
    for (final program in visiblePrograms) {
      // Gap before the program if it starts after the previous one ended.
      if (program.start.isAfter(lastEnd)) {
        final gapLeft = _durationToWidth(lastEnd.difference(gridStart));
        final gapWidth = _durationToWidth(program.start.difference(lastEnd));
        if (gapWidth > 0) {
          addIfVisible(gapLeft, gapWidth, () => _buildGap(gapWidth));
        }
      }

      final displayStart = program.start.isBefore(gridStart) ? gridStart : program.start;
      final displayEnd = program.end.isAfter(gridEnd) ? gridEnd : program.end;
      final cellWidth = _durationToWidth(displayEnd.difference(displayStart));
      if (cellWidth <= 0) continue;

      final cellLeft = _durationToWidth(displayStart.difference(gridStart));
      final hiddenLeftWidth = program.start.isBefore(gridStart)
          ? _durationToWidth(gridStart.difference(program.start))
          : 0.0;
      // Key by program id so element state (hover, text offset) cannot
      // migrate to a different program as the visibility window shifts.
      addIfVisible(
          cellLeft,
          cellWidth,
          () => _ProgramCell(
                program: program,
                width: cellWidth,
                height: _rowHeight,
                onTap: () => _showProgramDetails(context, program, channel),
                programStartOffset: cellLeft,
                hiddenLeftWidth: hiddenLeftWidth,
                scrollOffset: scrollOffset,
              ),
          key: ValueKey(program.id));

      // Track the furthest-right end so we don't double-paint gaps inside
      // overlapping ranges.
      if (program.end.isAfter(lastEnd)) lastEnd = program.end;
    }

    // Trailing gap from the last program end to the end of the grid.
    if (lastEnd.isBefore(gridEnd)) {
      final trailingLeft = _durationToWidth(lastEnd.difference(gridStart));
      final trailingWidth = _durationToWidth(gridEnd.difference(lastEnd));
      if (trailingWidth > 0) {
        addIfVisible(trailingLeft, trailingWidth, () => _buildGap(trailingWidth));
      }
    }

    return SizedBox(
      width: totalWidth,
      height: _rowHeight,
      child: Stack(clipBehavior: Clip.hardEdge, children: children),
    );
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

    // Clamp to the grid's actual range: it starts at _baseDate and covers
    // _daysToShow days, so past dates (or dates beyond the chips) would
    // select a day the grid cannot display.
    final lastDate = _baseDate.add(const Duration(days: _daysToShow - 1));
    final initialDate = selectedDate.isBefore(_baseDate)
        ? _baseDate
        : (selectedDate.isAfter(lastDate) ? lastDate : selectedDate);

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _baseDate,
      lastDate: lastDate,
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
      // Move the viewport too; updating the provider alone only changed the
      // highlighted chip.
      _scrollToDate(date);
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
    final playlists = ref.read(playlistNotifierProvider).valueOrNull ?? const [];
    final withEpg = playlists.where((p) => p.epgUrl != null && p.epgUrl!.isNotEmpty).toList();

    if (withEpg.isNotEmpty) {
      for (final playlist in withEpg) {
        ref.read(epgRefreshNotifierProvider.notifier).refreshEpg(playlist.id, playlist.epgUrl!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary))),
              const SizedBox(width: 12),
              Text(withEpg.length == 1 ? 'Refreshing EPG data...' : 'Refreshing EPG for ${withEpg.length} playlists...'),
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
          child: Container(
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
    return TvFocusable(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
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
    return TvFocusable(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
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
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: CachedNetworkImage(
                            imageUrl: widget.channel.logoUrl!,
                            fit: BoxFit.contain,
                            memCacheWidth: 80,
                            memCacheHeight: 80,
                            placeholder: (_, __) => Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Icon(Icons.tv_rounded, size: 18, color: AppColors.textMuted),
                          ),
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
  final double scrollOffset; // Current scroll offset for text alignment

  const _ProgramCell({required this.program, required this.width, required this.height, required this.onTap, this.programStartOffset = 0, this.hiddenLeftWidth = 0, this.scrollOffset = 0});

  @override
  State<_ProgramCell> createState() => _ProgramCellState();
}

class _ProgramCellState extends State<_ProgramCell> {
  bool _isHovered = false;
  double _lastCalculatedOffset = 0.0;

  // Cache DateFormat to avoid recreating on every build
  static final DateFormat _timeFormat = DateFormat.jm();

  @override
  void didUpdateWidget(covariant _ProgramCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Don't carry a text offset computed for a different program.
    if (oldWidget.program.id != widget.program.id) {
      _lastCalculatedOffset = 0.0;
    }
  }

  // Threshold for offset changes to trigger rebuild (pixels)
  // Higher threshold = fewer rebuilds = better performance
  static const double _offsetThreshold = 16.0;

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

    final viewportLeftEdge = scrollOffset;
    final cellLeftEdge = widget.programStartOffset;

    // For all programs, use smooth viewport edge alignment
    // This matches v1.0.2 behavior - text "sticks" to the viewport edge as you scroll
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

    return TvFocusable(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          width: widget.width,
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
          // Use regular Container instead of AnimatedContainer for better performance
          // AnimatedContainer on every cell causes significant overhead
          child: Container(
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
      // Vertical padding of 10 left the two text lines only 36px, ~3px short
      // of their natural height — every cell drew a debug overflow stripe.
      return Padding(
        padding: EdgeInsets.only(left: 10 + offset, right: 10, top: 7, bottom: 7),
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
            const SizedBox(height: 3),
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

    // Use sticky text alignment on all platforms
    // Scroll offset is passed from parent (no per-cell listeners needed)
    // Only apply to cells wider than 200px to avoid unnecessary calculations
    if (widget.width > 200) {
      final offset = _calculateTextOffset(widget.scrollOffset);
      return buildTextContent(offset);
    }

    // Narrow cells don't need sticky text
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
