import 'dart:typed_data';

/// TLV8 (Tag-Length-Value with 8-bit length) encoder and decoder.
///
/// Used by the HomeKit Accessory Protocol (HAP) for structured data
/// exchange during pair-setup and pair-verify flows.
///
/// Values longer than 255 bytes are automatically split across multiple
/// TLV entries with the same tag during encoding, and concatenated
/// during decoding.
class Tlv8 {
  Tlv8._();

  // -- HAP TLV Tags --

  /// Pairing method (e.g., PairSetup = 0).
  static const int tagMethod = 0x00;

  /// Pairing identifier (UTF-8 string).
  static const int tagIdentifier = 0x01;

  /// SRP salt (16 bytes).
  static const int tagSalt = 0x02;

  /// Public key (SRP or X25519).
  static const int tagPublicKey = 0x03;

  /// SRP proof.
  static const int tagProof = 0x04;

  /// Encrypted data (ChaCha20-Poly1305).
  static const int tagEncryptedData = 0x05;

  /// Sequence number (1-6).
  static const int tagSeqNo = 0x06;

  /// Error code.
  static const int tagError = 0x07;

  /// Ed25519 signature.
  static const int tagSignature = 0x0A;

  /// Pairing flags (e.g., transient = 0x10).
  static const int tagFlags = 0x13;

  /// Encodes a map of tag -> value pairs into a TLV8 byte array.
  ///
  /// Values longer than 255 bytes are automatically split into multiple
  /// consecutive entries with the same tag, each with at most 255 bytes.
  ///
  /// The [items] list preserves ordering. Each entry is a (tag, value) pair.
  static Uint8List encode(List<(int, List<int>)> items) {
    final builder = BytesBuilder(copy: false);

    for (final (tag, value) in items) {
      if (value.isEmpty) {
        builder.addByte(tag);
        builder.addByte(0);
        continue;
      }

      int offset = 0;
      while (offset < value.length) {
        final chunkSize =
            (value.length - offset) > 255 ? 255 : (value.length - offset);
        builder.addByte(tag);
        builder.addByte(chunkSize);
        builder.add(value.sublist(offset, offset + chunkSize));
        offset += chunkSize;
      }
    }

    return builder.toBytes();
  }

  /// Convenience: encodes from a map (ordering is map iteration order).
  static Uint8List encodeMap(Map<int, List<int>> map) {
    return encode(map.entries.map((e) => (e.key, e.value)).toList());
  }

  /// Decodes a TLV8 byte array into a map of tag -> concatenated value.
  ///
  /// Consecutive entries with the same tag are concatenated (this handles
  /// values that were split across multiple entries during encoding).
  static Map<int, List<int>> decode(List<int> data) {
    final result = <int, List<int>>{};
    int offset = 0;
    int? lastTag;

    while (offset < data.length) {
      if (offset + 1 >= data.length) {
        throw FormatException('TLV8: unexpected end of data at offset $offset');
      }

      final tag = data[offset];
      final length = data[offset + 1];
      offset += 2;

      if (offset + length > data.length) {
        throw FormatException(
          'TLV8: value overflows data at offset ${offset - 2} '
          '(tag=$tag, length=$length, remaining=${data.length - offset})',
        );
      }

      final value = data.sublist(offset, offset + length);
      offset += length;

      // Consecutive entries with the same tag are concatenated
      if (tag == lastTag && result.containsKey(tag)) {
        result[tag] = [...result[tag]!, ...value];
      } else {
        result[tag] = value;
      }
      lastTag = tag;
    }

    return result;
  }
}
