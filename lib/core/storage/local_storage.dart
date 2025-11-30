/// Abstract interface for local storage operations
abstract class LocalStorage {
  /// Initialize the storage
  Future<void> init();

  /// Get a value by key
  Future<T?> get<T>(String boxName, dynamic key);

  /// Put a value by key
  Future<void> put<T>(String boxName, dynamic key, T value);

  /// Delete a value by key
  Future<void> delete(String boxName, dynamic key);

  /// Get all values from a box
  Future<List<T>> getAll<T>(String boxName);

  /// Clear all values from a box
  Future<void> clear(String boxName);

  /// Check if a key exists
  Future<bool> containsKey(String boxName, dynamic key);

  /// Watch for changes on a key
  Stream<T?> watch<T>(String boxName, dynamic key);

  /// Close the storage
  Future<void> close();
}
