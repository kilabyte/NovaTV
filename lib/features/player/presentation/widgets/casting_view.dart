import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../playlist/domain/entities/channel.dart';
import '../providers/cast_providers.dart';

/// Full-screen placeholder shown on the player screen while a channel is being
/// cast to a Chromecast device. The video plays on the TV, so locally we show
/// the channel art, the device name, the now-playing program, and the remote
/// controls (play/pause, stop casting).
class CastingView extends ConsumerWidget {
  const CastingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cast = ref.watch(castProvider);
    final channel = cast.channel;
    final deviceName = cast.device?.name ?? 'Chromecast';

    final currentProgram = channel != null
        ? ref.watch(currentProgramProvider((
            playlistId: channel.playlistId,
            channelId: channel.epgId,
          )))
        : null;

    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Stack(
          children: [
            // Leave the player screen; casting continues and the global cast
            // bar takes over control in the app shell.
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28),
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ChannelArt(channel: channel),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cast.isBuffering ? Icons.cast_rounded : Icons.cast_connected_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cast.isBuffering ? 'Connecting to $deviceName…' : 'Casting to $deviceName',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    channel?.displayName ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (currentProgram?.value != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      currentProgram!.value!.title,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 32),
                  _Controls(isPlaying: cast.isPlaying, isBuffering: cast.isBuffering),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelArt extends StatelessWidget {
  final Channel? channel;

  const _ChannelArt({required this.channel});

  @override
  Widget build(BuildContext context) {
    final logo = channel?.logoUrl;
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(16),
      child: (logo != null && logo.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: logo,
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) => const _ArtFallback(),
            )
          : const _ArtFallback(),
    );
  }
}

class _ArtFallback extends StatelessWidget {
  const _ArtFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.live_tv_rounded, color: AppColors.textMuted, size: 56),
    );
  }
}

class _Controls extends ConsumerWidget {
  final bool isPlaying;
  final bool isBuffering;

  const _Controls({required this.isPlaying, required this.isBuffering});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play / pause
        _RoundButton(
          icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          primary: true,
          onTap: () => ref.read(castProvider.notifier).togglePlayPause(),
          tooltip: isPlaying ? 'Pause' : 'Play',
        ),
        const SizedBox(width: 20),
        // Stop casting (resumes local playback)
        _RoundButton(
          icon: Icons.stop_rounded,
          primary: false,
          onTap: () => ref.read(castProvider.notifier).stopCasting(),
          tooltip: 'Stop casting',
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;
  final String tooltip;

  const _RoundButton({
    required this.icon,
    required this.primary,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: primary ? AppColors.primary : AppColors.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: primary ? Colors.black : Colors.white,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}
