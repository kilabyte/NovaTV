import 'dart:io' show Platform;

import 'package:dart_cast/dart_cast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../providers/cast_providers.dart';

/// Opens the Chromecast device picker as a modal bottom sheet. Connecting to a
/// device selects it as the app's cast target: the channel currently playing
/// (if any) starts casting, and any channel opened afterwards casts to it too.
Future<void> showCastPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _CastDevicePickerSheet(),
  );
}

class _CastDevicePickerSheet extends ConsumerStatefulWidget {
  const _CastDevicePickerSheet();

  @override
  ConsumerState<_CastDevicePickerSheet> createState() =>
      _CastDevicePickerSheetState();
}

class _CastDevicePickerSheetState
    extends ConsumerState<_CastDevicePickerSheet> {
  @override
  void initState() {
    super.initState();
    // Kick off discovery once the sheet is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(castProvider.notifier).startDiscovery();
    });
  }

  @override
  void dispose() {
    // Stop scanning when the sheet closes (no-op / harmless once connected).
    ref.read(castProvider.notifier).stopDiscovery();
    super.dispose();
  }

  Future<void> _connect(CastDevice device) async {
    // Capture before we pop — the sheet's element is gone afterwards. The
    // notifier lives in the global provider, so calling it post-pop is safe.
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(castProvider.notifier);
    Navigator.of(context).pop();
    final error = await notifier.connectToDevice(device);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cast = ref.watch(castProvider);
    final isConnected = cast.isConnected;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.cast_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    isConnected ? 'Casting' : 'Cast to device',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (cast.phase == CastPhase.discovering)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(child: _buildBody(cast)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(CastState cast) {
    if (cast.isConnected && cast.device != null) {
      // Already casting: show the connected device + a stop action.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.cast_connected_rounded, color: AppColors.primary),
            title: Text(
              cast.device!.name,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              cast.channel?.displayName ?? 'Connected',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            trailing: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(castProvider.notifier).stopCasting();
              },
              child: const Text('Stop'),
            ),
          ),
        ],
      );
    }

    final devices = cast.devices;
    if (devices.isEmpty) {
      final isApple = Platform.isMacOS || Platform.isIOS;
      final emptyMsg = StringBuffer(
        'No devices found.\nMake sure your Chromecast is powered on and on the same Wi-Fi network.',
      );
      if (isApple) {
        emptyMsg.write(
          '\n\nIf it still does not appear, allow Nova IPTV to access the '
          'local network under System Settings > Privacy & Security > '
          'Local Network.',
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Text(
          cast.phase == CastPhase.discovering
              ? 'Searching for Chromecast devices…'
              : emptyMsg.toString(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.4),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return ListTile(
          leading: const Icon(Icons.tv_rounded, color: AppColors.textSecondary),
          title: Text(
            device.name,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            device.address.address,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          onTap: () => _connect(device),
        );
      },
    );
  }
}
