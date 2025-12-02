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

  // Initialize MediaKit
  AppLogger.debug('Initializing MediaKit...');
  MediaKit.ensureInitialized();

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
