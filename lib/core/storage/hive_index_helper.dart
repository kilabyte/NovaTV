import 'package:hive_ce/hive.dart';

/// Helper class for creating and maintaining Hive "indexes" using separate boxes
/// Since Hive doesn't support traditional indexes, we use separate boxes to
/// store key mappings for frequently queried fields
class HiveIndexHelper {
  /// Create an index box name for a specific field
  static String _indexBoxName(String baseBox, String field) {
    return '${baseBox}_index_$field';
  }

  /// Helper to open a Hive box with retry logic for lock errors
  static Future<Box<T>> _openBoxWithRetry<T>(String boxName, {int maxRetries = 2}) async {
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (Hive.isBoxOpen(boxName)) {
          return Hive.box<T>(boxName);
        }
        return await Hive.openBox<T>(boxName);
      } catch (e) {
        if (attempt < maxRetries - 1) {
          // Wait before retry
          await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
          // Try to close if open
          if (Hive.isBoxOpen(boxName)) {
            try {
              await Hive.box(boxName).close();
            } catch (_) {
              // Ignore close errors
            }
          }
        } else {
          rethrow;
        }
      }
    }
    throw Exception('Failed to open box after $maxRetries attempts');
  }

  /// Build an index for a specific field in a box
  /// This creates a separate box that maps field values to lists of keys
  /// Example: Index channels by group -> "Sports" -> [key1, key2, key3]
  static Future<void> buildIndex<T>({required String baseBoxName, required String fieldName, required String Function(T item) getFieldValue, required dynamic Function(T item) getKey}) async {
    final indexBoxName = _indexBoxName(baseBoxName, fieldName);
    final baseBox = await _openBoxWithRetry<T>(baseBoxName);
    final indexBox = await _openBoxWithRetry<List<dynamic>>(indexBoxName);

    // Clear existing index
    await indexBox.clear();

    // Build index: fieldValue -> [keys]
    final indexMap = <String, List<dynamic>>{};
    for (final key in baseBox.keys) {
      final item = baseBox.get(key);
      if (item != null) {
        final fieldValue = getFieldValue(item);
        if (fieldValue.isNotEmpty) {
          final normalizedValue = fieldValue.toLowerCase();
          final keys = indexMap.putIfAbsent(normalizedValue, () => <dynamic>[]);
          keys.add(getKey(item));
        }
      }
    }

    // Store index
    await indexBox.putAll(indexMap);
  }

  /// Get keys from an index for a specific field value
  static Future<List<dynamic>> getIndexedKeys({required String baseBoxName, required String fieldName, required String fieldValue}) async {
    final indexBoxName = _indexBoxName(baseBoxName, fieldName);
    if (!await Hive.boxExists(indexBoxName)) {
      return [];
    }

    final indexBox = await _openBoxWithRetry<List<dynamic>>(indexBoxName);
    final normalizedValue = fieldValue.toLowerCase();
    return indexBox.get(normalizedValue) ?? [];
  }

  /// Update index when an item is added/updated
  static Future<void> updateIndex<T>({required String baseBoxName, required String fieldName, required T item, required String Function(T item) getFieldValue, required dynamic Function(T item) getKey, String? oldFieldValue}) async {
    final indexBoxName = _indexBoxName(baseBoxName, fieldName);
    if (!await Hive.boxExists(indexBoxName)) {
      return; // Index doesn't exist yet
    }

    final indexBox = await _openBoxWithRetry<List<dynamic>>(indexBoxName);
    final newFieldValue = getFieldValue(item);
    final itemKey = getKey(item);

    // Remove from old index entry if field value changed
    if (oldFieldValue != null && oldFieldValue != newFieldValue) {
      final oldNormalized = oldFieldValue.toLowerCase();
      final oldKeys = indexBox.get(oldNormalized);
      if (oldKeys != null) {
        oldKeys.remove(itemKey);
        await indexBox.put(oldNormalized, oldKeys);
      }
    }

    // Add to new index entry
    if (newFieldValue.isNotEmpty) {
      final newNormalized = newFieldValue.toLowerCase();
      final keys = indexBox.get(newNormalized) ?? <dynamic>[];
      if (!keys.contains(itemKey)) {
        keys.add(itemKey);
        await indexBox.put(newNormalized, keys);
      }
    }
  }

  /// Remove from index when an item is deleted
  static Future<void> removeFromIndex({required String baseBoxName, required String fieldName, required String fieldValue, required dynamic key}) async {
    final indexBoxName = _indexBoxName(baseBoxName, fieldName);
    if (!await Hive.boxExists(indexBoxName)) {
      return;
    }

    final indexBox = await _openBoxWithRetry<List<dynamic>>(indexBoxName);
    final normalizedValue = fieldValue.toLowerCase();
    final keys = indexBox.get(normalizedValue);
    if (keys != null) {
      keys.remove(key);
      await indexBox.put(normalizedValue, keys);
    }
  }

  /// Delete an index
  static Future<void> deleteIndex({required String baseBoxName, required String fieldName}) async {
    final indexBoxName = _indexBoxName(baseBoxName, fieldName);
    if (await Hive.boxExists(indexBoxName)) {
      final indexBox = await Hive.openBox(indexBoxName);
      await indexBox.deleteFromDisk();
    }
  }

  /// Check if an index exists
  static Future<bool> indexExists({required String baseBoxName, required String fieldName}) async {
    final indexBoxName = _indexBoxName(baseBoxName, fieldName);
    return await Hive.boxExists(indexBoxName);
  }
}
