import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../config/router/routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../playlist/domain/entities/channel.dart';
import '../providers/player_providers.dart';

/// Mini-player widget for PiP within the app - TiVimate style
class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final showMiniPlayer = ref.watch(showMiniPlayerProvider);

    if (!showMiniPlayer || playerState.controller == null) {
      return const SizedBox.shrink();
    }

    final channel = playerState.channel;

    // Get current program if available
    final currentProgram = channel != null ? ref.watch(currentProgramProvider((playlistId: channel.playlistId, channelId: channel.epgId))) : null;

    // Get next program
    final nextProgram = channel != null ? ref.watch(nextProgramProvider((playlistId: channel.playlistId, channelId: channel.epgId))) : null;

    return Positioned(
      right: 16,
      bottom: 16,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: () {
            // Expand to full player
            ref.read(playerProvider.notifier).expand();
            context.push(Routes.playerPath(playerState.channel!.id));
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 400,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isHovered ? AppColors.primary : AppColors.border, width: _isHovered ? 2 : 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 8)),
                if (_isHovered) BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 4)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main content row
                IntrinsicHeight(
                  child: Row(
                    children: [
                      // Video thumbnail
                      SizedBox(
                        width: 140,
                        height: 110,
                        child: Stack(
                          children: [
                            // Video
                            Positioned.fill(
                              child: Video(controller: playerState.controller!, fit: BoxFit.cover, controls: NoVideoControls),
                            ),
                            // Live badge
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.live, borderRadius: BorderRadius.circular(4)),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, size: 4, color: Colors.white),
                                    SizedBox(width: 3),
                                    Text(
                                      'LIVE',
                                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Program info
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Channel name
                              Row(
                                children: [
                                  // Channel logo placeholder
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(4)),
                                    child: _buildChannelLogo(channel),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      channel?.displayName ?? 'Unknown',
                                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Current program
                              if (currentProgram?.value != null) ...[
                                Text(
                                  currentProgram!.value!.title,
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text('${_formatTime(currentProgram.value!.start)} - ${_formatTime(currentProgram.value!.end)} • ${currentProgram.value!.durationMinutes} min', style: TextStyle(color: AppColors.textMuted, fontSize: 10), maxLines: 1),
                              ] else ...[
                                Text('No program info', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              ],
                              // Up next
                              if (nextProgram?.value != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatTime(nextProgram!.value!.start)} ${nextProgram.value!.title}',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // Controls
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Play/Pause
                            _MiniPlayerButton(
                              icon: playerState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              onTap: () {
                                ref.read(playerProvider.notifier).togglePlayPause();
                              },
                              tooltip: playerState.isPlaying ? 'Pause' : 'Play',
                              isPrimary: true,
                            ),
                            const SizedBox(height: 4),
                            // Close
                            _MiniPlayerButton(
                              icon: Icons.close_rounded,
                              onTap: () {
                                ref.read(playerProvider.notifier).stop();
                              },
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Progress bar
                if (currentProgram?.value != null) _buildProgressBar(currentProgram!.value!),
                // Buffering indicator
                if (playerState.isBuffering) LinearProgressIndicator(minHeight: 2, backgroundColor: AppColors.surfaceElevated, valueColor: AlwaysStoppedAnimation(AppColors.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelLogo(Channel? channel) {
    if (channel?.logoUrl != null && channel!.logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          channel.logoUrl!,
          fit: BoxFit.contain,
          // Add caching for better performance
          cacheWidth: 100,
          cacheHeight: 100,
          errorBuilder: (_, __, ___) => Icon(Icons.live_tv_rounded, size: 14, color: AppColors.textMuted),
        ),
      );
    }
    return Icon(Icons.live_tv_rounded, size: 14, color: AppColors.textMuted);
  }

  Widget _buildProgressBar(dynamic program) {
    final now = DateTime.now();
    final start = program.start as DateTime;
    final end = program.end as DateTime;
    final totalDuration = end.difference(start).inSeconds;
    final elapsed = now.difference(start).inSeconds;
    final progress = (elapsed / totalDuration).clamp(0.0, 1.0);

    return Container(
      height: 3,
      decoration: BoxDecoration(color: AppColors.surfaceElevated),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(decoration: BoxDecoration(color: AppColors.primary)),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final amPm = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString()}:${time.minute.toString().padLeft(2, '0')} $amPm';
  }
}

class _MiniPlayerButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool isPrimary;

  const _MiniPlayerButton({required this.icon, required this.onTap, required this.tooltip, this.isPrimary = false});

  @override
  State<_MiniPlayerButton> createState() => _MiniPlayerButtonState();
}

class _MiniPlayerButtonState extends State<_MiniPlayerButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: widget.isPrimary
                  ? AppColors.primary
                  : _isHovered
                  ? AppColors.surfaceHover
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, color: widget.isPrimary ? Colors.black : AppColors.textPrimary, size: 18),
          ),
        ),
      ),
    );
  }
}
