import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'config/router/app_router.dart';
import 'config/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/storage/index_service.dart';
import 'core/utils/app_logger.dart';
import 'features/settings/presentation/providers/settings_providers.dart';

/// Main application widget with lifecycle management
class NovaApp extends ConsumerStatefulWidget {
  const NovaApp({super.key});

  @override
  ConsumerState<NovaApp> createState() => _NovaAppState();
}

class _NovaAppState extends ConsumerState<NovaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

    return ScreenUtilInit(
      designSize: const Size(375, 812), // iPhone X design size
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
            // Ensure text doesn't scale beyond reasonable limits
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(MediaQuery.of(context).textScaler.scale(1.0).clamp(0.8, 1.2))),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
