import 'dart:typed_data';

/// Persistent credentials produced by HAP pair-setup.
///
/// These credentials are stored after a successful pair-setup and reused
/// for subsequent pair-verify sessions without requiring a new PIN.
class HapCredentials {
  /// The client's Ed25519 private key (64 bytes: 32-byte seed + 32-byte pubkey).
  final Uint8List clientPrivateKey;

  /// The client's Ed25519 public key (32 bytes).
  final Uint8List clientPublicKey;

  /// The client's pairing identifier (UTF-8 string).
  final String clientId;

  /// The device's Ed25519 public key (32 bytes).
  final Uint8List devicePublicKey;

  /// The device's pairing identifier (UTF-8 string).
  final String deviceId;

  /// Creates [HapCredentials].
  HapCredentials({
    required this.clientPrivateKey,
    required this.clientPublicKey,
    required this.clientId,
    required this.devicePublicKey,
    required this.deviceId,
  });

  /// Serializes credentials to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'clientPrivateKey': _bytesToHex(clientPrivateKey),
    'clientPublicKey': _bytesToHex(clientPublicKey),
    'clientId': clientId,
    'devicePublicKey': _bytesToHex(devicePublicKey),
    'deviceId': deviceId,
  };

  /// Deserializes credentials from a JSON map.
  factory HapCredentials.fromJson(Map<String, dynamic> json) {
    return HapCredentials(
      clientPrivateKey: _hexToBytes(json['clientPrivateKey'] as String),
      clientPublicKey: _hexToBytes(json['clientPublicKey'] as String),
      clientId: json['clientId'] as String,
      devicePublicKey: _hexToBytes(json['devicePublicKey'] as String),
      deviceId: json['deviceId'] as String,
    );
  }

  /// Serializes to a pipe-separated hex string for compact storage.
  String serialize() {
    return [
      _bytesToHex(clientPrivateKey),
      _bytesToHex(clientPublicKey),
      clientId,
      _bytesToHex(devicePublicKey),
      deviceId,
    ].join('|');
  }

  /// Deserializes from a pipe-separated hex string.
  factory HapCredentials.deserialize(String data) {
    final parts = data.split('|');
    if (parts.length != 5) {
      throw FormatException(
        'Invalid HapCredentials format: expected 5 pipe-separated parts, '
        'got ${parts.length}',
      );
    }
    return HapCredentials(
      clientPrivateKey: _hexToBytes(parts[0]),
      clientPublicKey: _hexToBytes(parts[1]),
      clientId: parts[2],
      devicePublicKey: _hexToBytes(parts[3]),
      deviceId: parts[4],
    );
  }

  static String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _hexToBytes(String hex) {
    if (hex.length % 2 != 0) {
      throw FormatException('Invalid hex string length: ${hex.length}');
    }
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }

  @override
  String toString() =>
      'HapCredentials(clientId: $clientId, deviceId: $deviceId)';
}
