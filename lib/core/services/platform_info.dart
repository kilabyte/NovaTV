import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Platform info that needs a native call (specifically: is the current
/// device an Android TV?). Only Android matters here — every other platform
/// reports `isAndroidTv = false`.
class PlatformInfoService {
  static const MethodChannel _channel = MethodChannel('io.kilabyte.novatv/platform');

  Future<bool> isAndroidTv() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isAndroidTV');
      return result ?? false;
    } catch (_) {
      // If the channel isn't wired (older builds, hot-reload edge cases),
      // fall back to false rather than crashing.
      return false;
    }
  }
}

/// `true` when running on Android TV / Google TV. Cached for the life of
/// the provider container; the answer doesn't change at runtime.
final isAndroidTvProvider = FutureProvider<bool>((ref) {
  return PlatformInfoService().isAndroidTv();
});

/// Synchronous variant that defaults to `false` while the async detection
/// is still resolving. Most UI code prefers the sync read; the first frame
/// or two might briefly show a phone layout before flipping to TV layout.
final isAndroidTvSyncProvider = Provider<bool>((ref) {
  return ref.watch(isAndroidTvProvider).maybeWhen(
        data: (v) => v,
        orElse: () => false,
      );
});
