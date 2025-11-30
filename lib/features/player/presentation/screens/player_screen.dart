import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../shared/widgets/premium_widgets.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../playlist/domain/entities/channel.dart';
import '../../../playlist/presentation/providers/playlist_providers.dart';

/// Premium video player screen with glassmorphism controls
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
  late final Player _player;
  late final VideoController _controller;
  late final AnimationController _controlsAnimationController;
  late final Animation<double> _controlsAnimation;

  bool _showControls = true;
  bool _isInitialized = false;
  String? _errorMessage;
  Channel? _channel;
  bool _isPlaying = false;
  bool _isBuffering = false;

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
    _player = Player();
    _controller = VideoController(_player);

    // Hide system UI for immersive experience
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Listen to player state
    _player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() => _isPlaying = playing);
      }
    });

    _player.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() => _isBuffering = buffering);
      }
    });

    _player.stream.error.listen((error) {
      if (mounted && error.isNotEmpty) {
        setState(() => _errorMessage = error);
      }
    });

    // Load channel data
    await _loadChannel();
  }

  Future<void> _loadChannel() async {
    final repository = ref.read(playlistRepositoryProvider);
    final result = await repository.getChannel(widget.channelId);

    result.fold(
      (failure) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _errorMessage = failure.message;
          });
        }
      },
      (channel) async {
        if (mounted) {
          setState(() {
            _channel = channel;
            _isInitialized = true;
          });

          // Build HTTP headers if needed
          final httpHeaders = <String, String>{};
          if (channel.userAgent != null) {
            httpHeaders['User-Agent'] = channel.userAgent!;
          }
          if (channel.referrer != null) {
            httpHeaders['Referer'] = channel.referrer!;
          }
          if (channel.headers != null) {
            httpHeaders.addAll(channel.headers!);
          }

          // Open and play the stream
          await _player.open(
            Media(
              channel.url,
              httpHeaders: httpHeaders.isNotEmpty ? httpHeaders : null,
            ),
          );
        }
      },
    );

    // Start controls auto-hide timer
    _startControlsTimer();
  }

  void _startControlsTimer() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _showControls) {
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

  void _toggleFavorite() {
    if (_channel != null) {
      ref.read(favoriteNotifierProvider.notifier).toggleFavorite(_channel!.id);
      setState(() {
        _channel = _channel!.copyWith(isFavorite: !_channel!.isFavorite);
      });
    }
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
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.playerBackground,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Video player
            if (_isInitialized && _errorMessage == null)
              Center(
                child: Video(
                  controller: _controller,
                  fit: BoxFit.contain,
                ),
              )
            else if (_errorMessage != null)
              _buildErrorState()
            else
              _buildLoadingState(),

            // Premium buffering indicator
            if (_isBuffering && _errorMessage == null) _buildBufferingIndicator(),

            // Glassmorphism controls overlay
            if (_showControls)
              FadeTransition(
                opacity: _controlsAnimation,
                child: _buildPremiumControlsOverlay(),
              ),
          ],
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
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Connecting...',
            style: TextStyle(
              color: AppColors.darkOnSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBufferingIndicator() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Buffering...',
                  style: TextStyle(
                    color: AppColors.playerControls,
                    fontSize: 13,
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

  Widget _buildErrorState() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 1,
              ),
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
                Text(
                  'Unable to Play',
                  style: TextStyle(
                    color: AppColors.playerControls,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Unknown error occurred',
                  style: TextStyle(
                    color: AppColors.darkOnSurfaceVariant,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GlassButton(
                      onTap: () => Navigator.of(context).pop(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_rounded,
                            color: AppColors.playerControls,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Go Back',
                            style: TextStyle(
                              color: AppColors.playerControls,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _PrimaryButton(
                      onTap: () {
                        setState(() {
                          _errorMessage = null;
                          _isInitialized = false;
                        });
                        _loadChannel();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            color: AppColors.darkBackground,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Retry',
                            style: TextStyle(
                              color: AppColors.darkBackground,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumControlsOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.playerOverlay,
            Colors.transparent,
            Colors.transparent,
            AppColors.playerOverlay,
          ],
          stops: const [0.0, 0.25, 0.75, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top bar - Glassmorphism header
            _buildTopBar(),

            const Spacer(),

            // Center controls
            _buildCenterControls(),

            const Spacer(),

            // Bottom bar - Channel info and navigation
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.glassBackground,
            border: Border(
              bottom: BorderSide(
                color: AppColors.glassBorder,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              _GlassIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // LIVE badge for live content
                        const LiveBadge(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _channel?.displayName ?? 'Loading...',
                            style: TextStyle(
                              color: AppColors.playerControls,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (_channel?.group != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _channel!.group!,
                        style: TextStyle(
                          color: AppColors.darkOnSurfaceVariant,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (_channel != null) ...[
                _GlassIconButton(
                  icon: _channel!.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  iconColor: _channel!.isFavorite ? AppColors.accent : null,
                  onTap: _toggleFavorite,
                ),
                _GlassIconButton(
                  icon: Icons.more_vert_rounded,
                  onTap: _showOptionsSheet,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous channel
        _GlassControlButton(
          icon: Icons.skip_previous_rounded,
          size: 48,
          onTap: () {
            // TODO: Previous channel
          },
        ),
        const SizedBox(width: 32),
        // Play/Pause - Hero button
        GestureDetector(
          onTap: () => _player.playOrPause(),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: AppColors.gradientPrimary,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 40,
              color: AppColors.darkBackground,
            ),
          ),
        ),
        const SizedBox(width: 32),
        // Next channel
        _GlassControlButton(
          icon: Icons.skip_next_rounded,
          size: 48,
          onTap: () {
            // TODO: Next channel
          },
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    // Get current program if available
    final currentProgram = _channel != null
        ? ref.watch(currentProgramProvider((
            playlistId: _channel!.playlistId,
            channelId: _channel!.epgId,
          )))
        : null;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.glassBackground,
            border: Border(
              top: BorderSide(
                color: AppColors.glassBorder,
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Current program info
              if (currentProgram?.value != null) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'NOW',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentProgram!.value!.title,
                        style: TextStyle(
                          color: AppColors.playerControls,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Program progress bar
                _buildProgramProgress(currentProgram.value!),
                const SizedBox(height: 12),
              ],

              // Quick actions row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _QuickActionButton(
                    icon: Icons.aspect_ratio_rounded,
                    label: 'Aspect',
                    onTap: () => _showAspectRatioPicker(),
                  ),
                  _QuickActionButton(
                    icon: Icons.subtitles_rounded,
                    label: 'Subtitles',
                    onTap: () {},
                  ),
                  _QuickActionButton(
                    icon: Icons.audiotrack_rounded,
                    label: 'Audio',
                    onTap: () {},
                  ),
                  if (_channel?.hasCatchup == true)
                    _QuickActionButton(
                      icon: Icons.history_rounded,
                      label: 'Catchup',
                      onTap: () {},
                    ),
                  _QuickActionButton(
                    icon: Icons.tv_rounded,
                    label: 'Guide',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgramProgress(dynamic program) {
    final now = DateTime.now();
    final start = program.startTime as DateTime;
    final end = program.endTime as DateTime;
    final totalDuration = end.difference(start).inSeconds;
    final elapsed = now.difference(start).inSeconds;
    final progress = (elapsed / totalDuration).clamp(0.0, 1.0);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.darkBorder,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 3,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatTime(start),
              style: TextStyle(
                color: AppColors.darkOnSurfaceVariant,
                fontSize: 11,
              ),
            ),
            Text(
              _formatTime(end),
              style: TextStyle(
                color: AppColors.darkOnSurfaceVariant,
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

  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPremiumOptionsSheet(),
    );
  }

  Widget _buildPremiumOptionsSheet() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.darkSurface.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 0.5,
            ),
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
                    color: AppColors.darkOnSurfaceMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _PremiumOptionTile(
                  icon: Icons.aspect_ratio_rounded,
                  title: 'Aspect Ratio',
                  subtitle: 'Fit to screen',
                  onTap: () {
                    Navigator.pop(context);
                    _showAspectRatioPicker();
                  },
                ),
                _PremiumOptionTile(
                  icon: Icons.subtitles_rounded,
                  title: 'Subtitles',
                  subtitle: 'Off',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _PremiumOptionTile(
                  icon: Icons.audiotrack_rounded,
                  title: 'Audio Track',
                  subtitle: 'Default',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                if (_channel?.hasCatchup == true)
                  _PremiumOptionTile(
                    icon: Icons.history_rounded,
                    title: 'Catchup / Archive',
                    subtitle: 'Watch past programs',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                _PremiumOptionTile(
                  icon: Icons.info_outline_rounded,
                  title: 'Stream Info',
                  subtitle: _channel?.url.split('/').last ?? 'Unknown',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAspectRatioPicker() {
    showModalBottomSheet(
      context: context,
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
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.darkOnSurfaceMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Aspect Ratio',
                      style: TextStyle(
                        color: AppColors.playerControls,
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
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM PLAYER COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            color: iconColor ?? AppColors.playerControls,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _GlassControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _GlassControlButton({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.glassBackground,
              border: Border.all(
                color: AppColors.glassBorder,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: AppColors.playerControls,
              size: size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _GlassButton({
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.glassBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.gradientPrimary,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: AppColors.darkOnSurfaceVariant,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.darkOnSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PremiumOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.darkSurfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.playerControls,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.darkOnSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.darkOnSurfaceMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AspectRatioOption extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.darkOnSurfaceVariant,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.playerControls,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.darkOnSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
