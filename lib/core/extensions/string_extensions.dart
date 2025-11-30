/// Extension methods for String
extension StringExtensions on String {
  /// Check if string is a valid URL
  bool get isValidUrl {
    final urlPattern = RegExp(
      r'^(https?|ftp):\/\/[^\s/$.?#].[^\s]*$',
      caseSensitive: false,
    );
    return urlPattern.hasMatch(this);
  }

  /// Check if string is a valid M3U URL
  bool get isM3uUrl {
    return isValidUrl && (endsWith('.m3u') || endsWith('.m3u8') || contains('m3u'));
  }

  /// Check if string is a valid XMLTV URL
  bool get isXmltvUrl {
    return isValidUrl && (endsWith('.xml') || endsWith('.xml.gz') || contains('xmltv'));
  }

  /// Capitalize first letter
  String get capitalized {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Convert to title case
  String get titleCase {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalized).join(' ');
  }

  /// Truncate string with ellipsis
  String truncate(int maxLength, {String ellipsis = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - ellipsis.length)}$ellipsis';
  }

  /// Remove extra whitespace
  String get normalizeWhitespace {
    return replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Extract file extension
  String? get fileExtension {
    final lastDot = lastIndexOf('.');
    if (lastDot == -1 || lastDot == length - 1) return null;
    return substring(lastDot + 1).toLowerCase();
  }

  /// Check if string is empty or whitespace only
  bool get isBlank => trim().isEmpty;

  /// Check if string is not empty and not whitespace only
  bool get isNotBlank => !isBlank;
}

/// Extension methods for nullable String
extension NullableStringExtensions on String? {
  /// Returns true if string is null or empty
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  /// Returns true if string is null, empty, or whitespace only
  bool get isNullOrBlank => this == null || this!.isBlank;

  /// Returns the string or a default value if null/empty
  String orDefault(String defaultValue) {
    return isNullOrEmpty ? defaultValue : this!;
  }
}
