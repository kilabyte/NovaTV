import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';

import '../constants/storage_keys.dart';
import '../utils/app_logger.dart';

/// Service for managing window size and position persistence
class WindowService with WindowListener {
  static final WindowService _instance = WindowService._internal();
  factory WindowService() => _instance;
  WindowService._internal();

  Box? _settingsBox;
  bool _isInitialized = false;

  // Default window size
  static const double _defaultWidth = 1280.0;
  static const double _defaultHeight = 720.0;
  static const double _minWidth = 900.0;
  static const double _minHeight = 600.0;

  /// Initialize the window service
  Future<void> init() async {
    if (_isInitialized) return;

    // Only apply on desktop platforms
    if (!_isDesktop) {
      AppLogger.debug('WindowService: Not a desktop platform, skipping');
      return;
    }

    try {
      AppLogger.debug('WindowService: Initializing...');

      // Initialize window_manager
      await windowManager.ensureInitialized();

      // Open settings box
      _settingsBox = await Hive.openBox(StorageKeys.settingsBox);

      // Restore window settings
      await _restoreWindowSettings();

      // Set up window options
      await windowManager.setMinimumSize(const Size(_minWidth, _minHeight));
      await windowManager.setTitle('NovaIPTV');

      // Add listener for window changes
      windowManager.addListener(this);

      // Show window after setup
      await windowManager.show();
      await windowManager.focus();

      _isInitialized = true;
      AppLogger.info('WindowService: Initialized successfully');
    } catch (e, stack) {
      AppLogger.error('WindowService: Failed to initialize', e, stack);
    }
  }

  bool get _isDesktop {
    return !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
  }

  /// Restore window position and size from storage
  Future<void> _restoreWindowSettings() async {
    if (_settingsBox == null) return;

    try {
      final width = _settingsBox!.get(StorageKeys.windowWidth) as double?;
      final height = _settingsBox!.get(StorageKeys.windowHeight) as double?;
      final x = _settingsBox!.get(StorageKeys.windowX) as double?;
      final y = _settingsBox!.get(StorageKeys.windowY) as double?;
      final isMaximized = _settingsBox!.get(StorageKeys.windowMaximized) as bool? ?? false;

      if (width != null && height != null) {
        // Validate dimensions are reasonable
        final validWidth = width.clamp(_minWidth, 4000.0);
        final validHeight = height.clamp(_minHeight, 3000.0);

        await windowManager.setSize(Size(validWidth, validHeight));
        AppLogger.debug('WindowService: Restored size: ${validWidth}x$validHeight');
      } else {
        // Set default size
        await windowManager.setSize(const Size(_defaultWidth, _defaultHeight));
        AppLogger.debug('WindowService: Using default size');
      }

      // Restore position if available and valid
      if (x != null && y != null && x >= 0 && y >= 0) {
        await windowManager.setPosition(Offset(x, y));
        AppLogger.debug('WindowService: Restored position: ($x, $y)');
      } else {
        // Center the window
        await windowManager.center();
        AppLogger.debug('WindowService: Centering window');
      }

      // Restore maximized state
      if (isMaximized) {
        await windowManager.maximize();
        AppLogger.debug('WindowService: Restored maximized state');
      }
    } catch (e) {
      AppLogger.warning('WindowService: Failed to restore settings: $e');
      // Fall back to defaults
      await windowManager.setSize(const Size(_defaultWidth, _defaultHeight));
      await windowManager.center();
    }
  }

  /// Save current window settings to storage
  Future<void> _saveWindowSettings() async {
    if (_settingsBox == null) return;

    try {
      final isMaximized = await windowManager.isMaximized();

      // Only save size/position if not maximized
      if (!isMaximized) {
        final size = await windowManager.getSize();
        final position = await windowManager.getPosition();

        await _settingsBox!.put(StorageKeys.windowWidth, size.width);
        await _settingsBox!.put(StorageKeys.windowHeight, size.height);
        await _settingsBox!.put(StorageKeys.windowX, position.dx);
        await _settingsBox!.put(StorageKeys.windowY, position.dy);
      }

      await _settingsBox!.put(StorageKeys.windowMaximized, isMaximized);

      AppLogger.debug('WindowService: Saved window settings');
    } catch (e) {
      AppLogger.warning('WindowService: Failed to save settings: $e');
    }
  }

  // WindowListener callbacks

  @override
  void onWindowResized() {
    _saveWindowSettings();
  }

  @override
  void onWindowMoved() {
    _saveWindowSettings();
  }

  @override
  void onWindowMaximize() {
    _saveWindowSettings();
  }

  @override
  void onWindowUnmaximize() {
    _saveWindowSettings();
  }

  @override
  void onWindowClose() {
    _saveWindowSettings();
  }

  /// Clean up
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
  }
}
