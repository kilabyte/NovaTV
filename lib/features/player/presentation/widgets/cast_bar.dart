import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../providers/cast_providers.dart';

/// Persistent control bar shown anywhere in the app shell while a channel is
/// casting to a Chromecast device. The full-screen player route lives outside
/// the shell, so this is the cast control surface while the user browses
/// channels / the guide. Tapping it opens the player screen's casting view.
class CastBar extends ConsumerWidget {
  const CastBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cast = ref.watch(castProvider);
    if (!cast.isCasting) return const SizedBox.shrink();

    final channel = cast.channel;
    final deviceName = cast.device?.name ?? 'Chromecast';

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                // Info area — tap to open the casting view on the player route.
                Expanded(
                  child: InkWell(
                    onTap: channel == null
                        ? null
                        : () => context.push(Routes.playerPath(channel.id)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                      child: Row(
                        children: [
                          Icon(
                            cast.isBuffering
                                ? Icons.cast_rounded
                                : Icons.cast_connected_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  channel == null
                                      ? 'Connected to $deviceName'
                                      : cast.isBuffering
                                          ? 'Connecting to $deviceName…'
                                          : 'Casting to $deviceName',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  channel?.displayName ??
                                      'Play a channel to start casting',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Play / pause (only once a channel is loaded on the device)
                if (channel != null)
                  _BarButton(
                    icon: cast.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    tooltip: cast.isPlaying ? 'Pause' : 'Play',
                    onTap: () =>
                        ref.read(castProvider.notifier).togglePlayPause(),
                  ),
                // Stop casting
                _BarButton(
                  icon: Icons.stop_rounded,
                  tooltip: 'Stop casting',
                  onTap: () => ref.read(castProvider.notifier).stopCasting(),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _BarButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: AppColors.textPrimary, size: 24),
      tooltip: tooltip,
      onPressed: onTap,
      splashRadius: 22,
    );
  }
}
