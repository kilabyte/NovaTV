import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/services/pip_service.dart';
import '../providers/player_providers.dart';

/// Full-screen bare-video overlay shown while the app is inside the OS
/// picture-in-picture window. The PiP window renders the whole activity
/// scaled down, so without this the tiny window would show the TV guide or
/// the player screen's controls instead of just the video.
class SystemPipOverlay extends ConsumerWidget {
  const SystemPipOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inSystemPip = ref.watch(systemPipActiveProvider);
    final controller = ref.watch(playerProvider.select((s) => s.controller));
    if (!inSystemPip || controller == null) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black,
        child: Video(
          controller: controller,
          fit: BoxFit.contain,
          controls: NoVideoControls,
        ),
      ),
    );
  }
}
