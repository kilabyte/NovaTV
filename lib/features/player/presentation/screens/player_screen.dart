import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../epg/domain/entities/program.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../playlist/presentation/providers/playlist_providers.dart';
import '../providers/player_providers.dart';

/// Clean video player screen using global player state for mini-player support
class PlayerScreen extends ConsumerStatefulWidget {
  final String channelId;

  const PlayerScreen({
    super.key,
    required this.channelId,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlsAnimationController;
  late final Animation<double> _controlsAnimation;

  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlsAnimation = CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeOutCubic,
    );
    _controlsAnimationController.forward();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    // Hide system UI for immersive experience
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Use global player provider
    final playerState = ref.read(playerProvider);

    // Only start playback if not already playing this channel
    if (playerState.channel?.id != widget.channelId) {
      await ref.read(playerProvider.notifier).playChannel(widget.channelId);
    } else {
      // Already playing this channel, just expand it
      ref.read(playerProvider.notifier).expand();
    }

    // Start controls auto-hide timer
    _startControlsTimer();
  }

  void _startControlsTimer() {
    Future.delayed(const Duration(seconds: 5), () {
      // Don't hide controls if mouse is still inside the player area (desktop)
      if (mounted && _showControls && !_isMouseInside) {
        _hideControls();
      }
    });
  }

  void _hideControls() {
    _controlsAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    if (_showControls) {
      _hideControls();
    } else {
      setState(() => _showControls = true);
      _controlsAnimationController.forward();
      _startControlsTimer();
    }
  }

  /// Check if we're on a desktop platform
  bool get _isDesktop {
    return !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
  }

  // Track if mouse is inside the player area
  bool _isMouseInside = false;

  /// Show controls on mouse hover (desktop only)
  void _showControlsOnHover() {
    _isMouseInside = true;
    if (!_showControls) {
      setState(() => _showControls = true);
      _controlsAnimationController.forward();
    }
    // Don't auto-hide while mouse is inside - only restart timer when mouse moves but stays inside
  }

  /// Hide controls when mouse exits player area (desktop only)
  void _hideControlsOnHoverExit() {
    _isMouseInside = false;
    // Start the hide timer when mouse exits
    _startControlsTimer();
  }

  void _toggleFavorite() {
    final channel = ref.read(playerProvider).channel;
    if (channel != null) {
      ref.read(favoriteNotifierProvider.notifier).toggleFavorite(channel.id);
    }
  }

  void _minimizePlayer() {
    // Minimize to PiP instead of closing
    // Clear any error state when going back
    ref.read(playerProvider.notifier).minimize();
    if (context.mounted) {
      context.pop();
    }
  }

  void _closePlayer() {
    // Stop playback completely and close
    ref.read(playerProvider.notifier).stop();
    context.pop();
  }

  @override
  void dispose() {
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _controlsAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final channel = playerState.channel;
    final controller = playerState.controller;
    final isInitialized = controller != null;
    final errorMessage = playerState.errorMessage;

    return PopScope(
      // Handle Android back button - allow going back even when there's an error
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          // Clear error state when popping
          ref.read(playerProvider.notifier).minimize();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        // Wrap the entire body in MouseRegion to track mouse position consistently
        // This prevents the controls overlay from interfering with hover detection
        body: MouseRegion(
        onEnter: _isDesktop ? (_) => _showControlsOnHover() : null,
        onExit: _isDesktop ? (_) => _hideControlsOnHoverExit() : null,
        child: Stack(
          children: [
            // Video player
            if (isInitialized && errorMessage == null)
              Center(
                child: Video(
                  controller: controller,
                  fit: BoxFit.contain,
                  // Disable built-in controls - we use our own
                  controls: NoVideoControls,
                ),
              )
            else if (errorMessage != null)
              _buildErrorState(errorMessage)
            else
              _buildLoadingState(),

            // Transparent tap layer to toggle controls (tap anywhere)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleControls,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),

            // Buffering indicator
            if (playerState.isBuffering && errorMessage == null)
              _buildBufferingIndicator(),

            // Controls overlay (fades in/out) - always rendered but with opacity animation
            // Using IgnorePointer only for the background gradient to allow button clicks
            FadeTransition(
              opacity: _controlsAnimation,
              child: _showControls
                  ? _buildControlsOverlay(playerState, channel)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      ),
    );
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
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Connecting...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBufferingIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Buffering...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Unable to Play',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: _minimizePlayer,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'Go Back',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    // Show loading state while retrying
                    await ref.read(playerProvider.notifier).retry();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay(PlayerState playerState, dynamic channel) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.8),
          ],
          stops: const [0.0, 0.2, 0.75, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top bar
            _buildTopBar(playerState, channel),

            const Spacer(),

            // Bottom bar with play/pause
            _buildBottomBar(channel, playerState),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(PlayerState playerState, dynamic channel) {
    final isFavorite = ref.watch(isFavoriteProvider(channel?.id ?? '')).valueOrNull ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // PiP minimize button
          _MinimizeButton(onTap: _minimizePlayer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // LIVE badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.live,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 6, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        channel?.displayName ?? 'Loading...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (channel?.group != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    channel!.group!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (channel != null) ...[
            _ControlIconButton(
              icon: isFavorite
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              iconColor: isFavorite ? AppColors.favorite : null,
              onTap: _toggleFavorite,
            ),
            _ControlIconButton(
              icon: Icons.more_vert_rounded,
              onTap: _showOptionsSheet,
            ),
            _CloseButton(onTap: _closePlayer),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(dynamic channel, PlayerState playerState) {
    // Get current and next program if available
    final currentProgram = channel != null
        ? ref.watch(currentProgramProvider((
            playlistId: channel.playlistId,
            channelId: channel.epgId,
          )))
        : null;

    final nextProgram = channel != null
        ? ref.watch(nextProgramProvider((
            playlistId: channel.playlistId,
            channelId: channel.epgId,
          )))
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Current program info
          if (currentProgram?.value != null) ...[
            // Title and time row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    'NOW',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    currentProgram!.value!.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Duration badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${currentProgram.value!.durationMinutes} min',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            // Description
            if (currentProgram.value!.description != null &&
                currentProgram.value!.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                currentProgram.value!.description!,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            _buildProgramProgress(currentProgram.value!),
          ],

          // Up Next section with play/pause button
          const SizedBox(height: 16),
          Row(
            children: [
              // Up Next - tappable to show full EPG
              if (nextProgram?.value != null)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showChannelEpgSheet(channel),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'UP NEXT',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.expand_less_rounded,
                                  size: 14,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatTime(nextProgram!.value!.start),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              nextProgram.value!.title,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              // Play/Pause button on the right
              const SizedBox(width: 16),
              _SmallPlayPauseButton(
                isPlaying: playerState.isPlaying,
                onTap: () => ref.read(playerProvider.notifier).togglePlayPause(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgramProgress(dynamic program) {
    final now = DateTime.now();
    final start = program.start as DateTime;
    final end = program.end as DateTime;
    final totalDuration = end.difference(start).inSeconds;
    final elapsed = now.difference(start).inSeconds;
    final progress = (elapsed / totalDuration).clamp(0.0, 1.0);

    return Column(
      children: [
        // Progress bar
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatTime(start),
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
            Text(
              _formatTime(end),
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showChannelEpgSheet(dynamic channel) {
    if (channel == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChannelEpgSheet(
        channelName: channel.displayName ?? 'Unknown',
        playlistId: channel.playlistId ?? '',
        channelId: channel.epgId ?? '',
      ),
    );
  }

  void _showOptionsSheet() {
    final channel = ref.read(playerProvider).channel;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildOptionsSheet(channel),
    );
  }

  Widget _buildOptionsSheet(dynamic channel) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _OptionTile(
              icon: Icons.aspect_ratio_rounded,
              title: 'Aspect Ratio',
              subtitle: 'Fit to screen',
              onTap: () {
                Navigator.pop(context);
                _showAspectRatioPicker();
              },
            ),
            _OptionTile(
              icon: Icons.subtitles_rounded,
              title: 'Subtitles',
              subtitle: 'Off',
              onTap: () => Navigator.pop(context),
            ),
            _OptionTile(
              icon: Icons.audiotrack_rounded,
              title: 'Audio Track',
              subtitle: 'Default',
              onTap: () => Navigator.pop(context),
            ),
            if (channel?.hasCatchup == true)
              _OptionTile(
                icon: Icons.history_rounded,
                title: 'Catchup / Archive',
                subtitle: 'Watch past programs',
                onTap: () => Navigator.pop(context),
              ),
            _OptionTile(
              icon: Icons.info_outline_rounded,
              title: 'Stream Info',
              subtitle: channel?.url.split('/').last ?? 'Unknown',
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showAspectRatioPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Aspect Ratio',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _AspectRatioOption(
                icon: Icons.fit_screen_rounded,
                title: 'Fit to Screen',
                subtitle: 'Show entire video',
                isSelected: true,
                onTap: () => Navigator.pop(context),
              ),
              _AspectRatioOption(
                icon: Icons.fullscreen_rounded,
                title: 'Fill Screen',
                subtitle: 'May crop edges',
                isSelected: false,
                onTap: () => Navigator.pop(context),
              ),
              _AspectRatioOption(
                icon: Icons.crop_16_9_rounded,
                title: '16:9 Widescreen',
                subtitle: 'Standard HD ratio',
                isSelected: false,
                onTap: () => Navigator.pop(context),
              ),
              _AspectRatioOption(
                icon: Icons.crop_square_rounded,
                title: '4:3 Standard',
                subtitle: 'Classic TV ratio',
                isSelected: false,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PLAYER COMPONENTS - Clean Solid Design
// ═══════════════════════════════════════════════════════════════════════════

/// Always visible minimize button in top-left corner
class _MinimizeButton extends StatefulWidget {
  final VoidCallback onTap;

  const _MinimizeButton({required this.onTap});

  @override
  State<_MinimizeButton> createState() => _MinimizeButtonState();
}

class _MinimizeButtonState extends State<_MinimizeButton> {
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _isHovered
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(
            Icons.picture_in_picture_alt_rounded,
            color: _isHovered ? AppColors.primary : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// Close button to stop playback completely
class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.error.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered
                  ? AppColors.error.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(
            Icons.close_rounded,
            color: _isHovered ? AppColors.error : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _ControlIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _ControlIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  State<_ControlIconButton> createState() => _ControlIconButtonState();
}

class _ControlIconButtonState extends State<_ControlIconButton> {
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _isHovered ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            widget.icon,
            color: widget.iconColor ?? Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// Small play/pause button for bottom right of player
class _SmallPlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _SmallPlayPauseButton({
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<_SmallPlayPauseButton> createState() => _SmallPlayPauseButtonState();
}

class _SmallPlayPauseButtonState extends State<_SmallPlayPauseButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.diagonal3Values(
            _isPressed ? 0.92 : 1.0,
            _isPressed ? 0.92 : 1.0,
            1.0,
          ),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 28,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: _isHovered ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.icon,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AspectRatioOption extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _AspectRatioOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AspectRatioOption> createState() => _AspectRatioOptionState();
}

class _AspectRatioOptionState extends State<_AspectRatioOption> {
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: widget.isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : _isHovered
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.transparent,
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// EPG Sheet for showing channel program schedule
class _ChannelEpgSheet extends ConsumerWidget {
  final String channelName;
  final String playlistId;
  final String channelId;

  const _ChannelEpgSheet({
    required this.channelName,
    required this.playlistId,
    required this.channelId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programsAsync = ref.watch(channelProgramsProvider((
      playlistId: playlistId,
      channelId: channelId,
    )));

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.schedule_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channelName,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Program Schedule',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.border),
            // Program list
            Expanded(
              child: programsAsync.when(
                data: (programs) {
                  if (programs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy_rounded,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No program data available',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Filter to show programs from now onwards and sort
                  final now = DateTime.now();
                  final upcomingPrograms = programs
                      .where((p) => p.end.isAfter(now))
                      .toList()
                    ..sort((a, b) => a.start.compareTo(b.start));

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: upcomingPrograms.length,
                    itemBuilder: (context, index) {
                      final program = upcomingPrograms[index];
                      return _EpgProgramTile(program: program);
                    },
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load programs',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpgProgramTile extends StatelessWidget {
  final Program program;

  const _EpgProgramTile({required this.program});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat.jm();
    final isAiring = program.isCurrentlyAiring;
    final hasEnded = program.hasEnded;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAiring
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.surfaceElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAiring
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeFormat.format(program.start),
                  style: TextStyle(
                    color: isAiring ? AppColors.primary : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: isAiring ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                Text(
                  timeFormat.format(program.end),
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Program info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isAiring) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColors.live,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'NOW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        program.title,
                        style: TextStyle(
                          color: hasEnded
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: isAiring ? FontWeight.w600 : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (program.description != null &&
                    program.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    program.description!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${program.durationMinutes} min',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
