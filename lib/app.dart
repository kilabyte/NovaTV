import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'config/router/app_router.dart';
import 'config/router/routes.dart';
import 'config/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/services/now_playing_service.dart';
import 'core/services/pip_service.dart';
import 'core/services/platform_info.dart';
import 'core/storage/index_service.dart';
import 'core/utils/app_logger.dart';
import 'features/player/presentation/widgets/system_pip_overlay.dart';
import 'features/settings/presentation/providers/settings_providers.dart';
import 'shared/widgets/startup_refresh.dart';

/// Main application widget with lifecycle management
class NovaApp extends ConsumerStatefulWidget {
  const NovaApp({super.key});

  @override
  ConsumerState<NovaApp> createState() => _NovaAppState();
}

class _NovaAppState extends ConsumerState<NovaApp> with WidgetsBindingObserver {
  /// Channel that receives native macOS menu events (e.g. Preferences).
  static const MethodChannel _menuChannel = MethodChannel('io.kilabyte.novatv/menu');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Kick off the startup refresh here rather than only from AppShell so
    // deep-link launches (e.g. /player/:id) also pick up stale data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      performStartupRefresh(ref);
    });

    // Listen for Cmd+, from the macOS menu bar.
    if (!kIsWeb && Platform.isMacOS) {
      _menuChannel.setMethodCallHandler(_handleMenuCall);
      // Start the Now Playing / media-keys bridge. It listens for player
      // state changes and forwards them to MPNowPlayingInfoCenter.
      ref.read(nowPlayingServiceProvider);
    }

    // Start the system picture-in-picture bridge. It pushes playback
    // eligibility to MainActivity so swiping home while a channel plays
    // hands the video off to the OS PiP window.
    if (!kIsWeb && Platform.isAndroid) {
      ref.read(pipServiceProvider);
    }
  }

  Future<void> _handleMenuCall(MethodCall call) async {
    if (call.method == 'openSettings') {
      // Use the router directly rather than relying on a BuildContext so this
      // works whether or not a route is currently focused.
      ref.read(appRouterProvider).go(Routes.settings);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // App resumed from background/suspend
        AppLogger.debug('App resumed, validating indexes...');
        // Validate indexes in background (non-blocking)
        IndexService.validateIndexesOnResume().catchError((error) {
          AppLogger.warning('Index validation on resume failed (non-critical): $error');
        });
        break;
      case AppLifecycleState.paused:
        // App paused (going to background)
        AppLogger.debug('App paused');
        break;
      case AppLifecycleState.inactive:
        // App inactive (transitioning states)
        break;
      case AppLifecycleState.detached:
        // App detached (terminated)
        AppLogger.debug('App detached');
        break;
      case AppLifecycleState.hidden:
        // App hidden (iOS specific)
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);
    final isTv = ref.watch(isAndroidTvSyncProvider);

    return ScreenUtilInit(
      // 10-foot UI: TV viewers sit further from the screen, so scale the
      // design baseline up. Keeps every layout (sized via ScreenUtil's .sp /
      // .w / .h) bigger without per-screen if-branches.
      designSize: isTv ? const Size(640, 360) : const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,

          // Theme configuration
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,

          // Router configuration
          routerConfig: router,

          // Builder for global overlays
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            // TV: bump text scaling so default Material body sizes (~14sp)
            // read clearly from the couch. Phone keeps its existing clamp.
            final scaler = isTv
                ? TextScaler.linear(mq.textScaler.scale(1.25).clamp(1.1, 1.4))
                : TextScaler.linear(mq.textScaler.scale(1.0).clamp(0.8, 1.2));
            return MediaQuery(
              data: mq.copyWith(textScaler: scaler),
              child: Stack(
                children: [
                  child ?? const SizedBox.shrink(),
                  // While the OS picture-in-picture window is active the
                  // whole activity is rendered tiny, so cover everything
                  // with bare video.
                  const SystemPipOverlay(),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
