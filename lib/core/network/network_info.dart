/// Abstract interface for checking network connectivity
abstract class NetworkInfo {
  /// Check if the device is connected to the internet
  Future<bool> get isConnected;

  /// Stream of connectivity changes
  Stream<bool> get onConnectivityChanged;
}

/// Simple implementation that assumes network is available
/// In a production app, you would use connectivity_plus package
class NetworkInfoImpl implements NetworkInfo {
  @override
  Future<bool> get isConnected async {
    // In production, use connectivity_plus to check actual connectivity
    // For now, we assume network is available
    return true;
  }

  @override
  Stream<bool> get onConnectivityChanged {
    // In production, use connectivity_plus to monitor connectivity changes
    return Stream.value(true);
  }
}
