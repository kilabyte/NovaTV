import 'package:hive_ce_flutter/hive_flutter.dart';
import 'local_storage.dart';
import '../constants/storage_keys.dart';
import '../../hive_registrar.g.dart';
import '../../features/playlist/data/models/playlist_model.dart';
import '../../features/settings/data/models/app_settings_model.dart';

/// Global helper to safely open a Hive box with retry logic for lock errors.
/// Use this instead of Hive.openBox directly throughout the app.
Future<Box<T>> safeOpenBox<T>(String boxName, {int maxRetries = 3}) async {
  for (var attempt = 0; attempt < maxRetries; attempt++) {
    try {
      // Return existing box if already open
      if (Hive.isBoxOpen(boxName)) {
        return Hive.box<T>(boxName);
      }
      return await Hive.openBox<T>(boxName);
    } catch (e) {
      if (attempt < maxRetries - 1) {
        // Wait with exponential backoff before retry
        await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
        // Try to close if somehow half-open
        if (Hive.isBoxOpen(boxName)) {
          try {
            await Hive.box(boxName).close();
          } catch (_) {
            // Ignore close errors
          }
        }
      } else {
        // Last attempt failed, rethrow
        rethrow;
      }
    }
  }
  throw Exception('Failed to open box "$boxName" after $maxRetries attempts');
}

/// Hive implementation of local storage
class HiveStorage implements LocalStorage {
  final Map<String, Box> _openBoxes = {};

  @override
  Future<void> init() async {
    await Hive.initFlutter();

    // Register all Hive adapters using the generated registrar
    Hive.registerAdapters();

    // Pre-open essential boxes that are needed immediately at app startup
    // This ensures they're available when the router is created
    await safeOpenBox<PlaylistModel>('playlists');
    await safeOpenBox<AppSettingsModel>('app_settings');
  }

  Future<Box<T>> _getBox<T>(String boxName) async {
    if (_openBoxes.containsKey(boxName)) {
      final box = _openBoxes[boxName];
      if (box is Box<T> && box.isOpen) {
        return box;
      }
    }
    final box = await safeOpenBox<T>(boxName);
    _openBoxes[boxName] = box;
    return box;
  }

  @override
  Future<T?> get<T>(String boxName, dynamic key) async {
    final box = await _getBox<T>(boxName);
    return box.get(key);
  }

  @override
  Future<void> put<T>(String boxName, dynamic key, T value) async {
    final box = await _getBox<T>(boxName);
    await box.put(key, value);
  }

  @override
  Future<void> delete(String boxName, dynamic key) async {
    final box = await _getBox(boxName);
    await box.delete(key);
  }

  @override
  Future<List<T>> getAll<T>(String boxName) async {
    final box = await _getBox<T>(boxName);
    return box.values.toList();
  }

  @override
  Future<void> clear(String boxName) async {
    final box = await _getBox(boxName);
    await box.clear();
  }

  @override
  Future<bool> containsKey(String boxName, dynamic key) async {
    final box = await _getBox(boxName);
    return box.containsKey(key);
  }

  @override
  Stream<T?> watch<T>(String boxName, dynamic key) async* {
    final box = await _getBox<T>(boxName);
    yield box.get(key);
    yield* box.watch(key: key).map((event) => event.value as T?);
  }

  @override
  Future<void> close() async {
    for (final box in _openBoxes.values) {
      await box.close();
    }
    _openBoxes.clear();
  }

  /// Open a specific settings box for simple key-value storage
  Future<Box> openSettingsBox() async {
    return _getBox(StorageKeys.settingsBox);
  }
}
