import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart';

import 'core/services/window_service.dart';
import 'core/storage/hive_storage.dart';
import 'core/utils/app_logger.dart';

/// Bootstrap the application
/// Initializes all required services before the app starts
Future<void> bootstrap() async {
  AppLogger.info('Starting NovaIPTV bootstrap...');

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize MediaKit with buffer configuration to reduce stuttering
  // Configure mpv buffer settings via environment variables for better streaming performance
  AppLogger.debug('Initializing MediaKit...');
  MediaKit.ensureInitialized();
  
  // Note: Buffer configuration for media_kit/mpv can be set via:
  // - MPV_CONFIG_DIR environment variable pointing to mpv config directory
  // - Or mpv config file with settings like:
  //   cache=yes
  //   demuxer-max-bytes=52428800  # 50MB cache
  //   demuxer-max-back-bytes=26214400  # 25MB back buffer
  //   network-timeout=30  # 30 second timeout
  // These settings help reduce stuttering by preloading more data

  // Initialize Hive storage
  AppLogger.debug('Initializing Hive storage...');
  final storage = HiveStorage();
  await storage.init();

  // Initialize window service (for window size persistence on desktop)
  AppLogger.debug('Initializing window service...');
  final windowService = WindowService();
  await windowService.init();

  // Set log level based on build mode
  if (kReleaseMode) {
    AppLogger.setLevel(Level.warning);
  }

  AppLogger.info('Bootstrap complete!');
}
