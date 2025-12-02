import 'package:hive_ce_flutter/hive_flutter.dart';
import 'local_storage.dart';
import '../constants/storage_keys.dart';
import '../../hive_registrar.g.dart';
import '../../features/playlist/data/models/playlist_model.dart';
import '../../features/settings/data/models/app_settings_model.dart';

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
    await Hive.openBox<PlaylistModel>('playlists');
    await Hive.openBox<AppSettingsModel>('app_settings');
  }

  Future<Box<T>> _getBox<T>(String boxName) async {
    if (_openBoxes.containsKey(boxName)) {
      return _openBoxes[boxName] as Box<T>;
    }
    final box = await Hive.openBox<T>(boxName);
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
