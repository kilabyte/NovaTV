/// Parsed SSDP response containing extracted header values.
class SsdpResponse {
  /// URL to the device description XML.
  final String? location;

  /// Unique Service Name identifying the device/service.
  final String? usn;

  /// Search Target that matched the query.
  final String? st;

  /// All headers from the response, keyed in lowercase.
  final Map<String, String> headers;

  SsdpResponse({this.location, this.usn, this.st, this.headers = const {}});
}

/// Constants for SSDP multicast discovery.
class SsdpConstants {
  SsdpConstants._();

  /// SSDP multicast address.
  static const String multicastAddress = '239.255.255.250';

  /// SSDP multicast port.
  static const int multicastPort = 1900;

  /// Common search target values for discovering DLNA devices.
  static const List<String> searchTargets = [
    'ssdp:all',
    'upnp:rootdevice',
    'urn:schemas-upnp-org:device:MediaRenderer:1',
    'urn:schemas-upnp-org:service:AVTransport:1',
  ];
}

/// Static methods for formatting and parsing SSDP messages.
class SsdpMessage {
  SsdpMessage._();

  /// Formats an M-SEARCH request string.
  ///
  /// [st] is the search target (e.g., `urn:schemas-upnp-org:device:MediaRenderer:1`).
  /// [mx] is the maximum wait time in seconds before a device must respond.
  static String mSearch(String st, int mx) {
    return 'M-SEARCH * HTTP/1.1\r\n'
        'HOST: ${SsdpConstants.multicastAddress}:${SsdpConstants.multicastPort}\r\n'
        'MAN: "ssdp:discover"\r\n'
        'ST: $st\r\n'
        'MX: $mx\r\n'
        '\r\n';
  }

  /// Parses an SSDP response (HTTP 200 OK or NOTIFY) into an [SsdpResponse].
  ///
  /// Headers are matched case-insensitively. Returns an [SsdpResponse] with
  /// null fields if the data cannot be parsed.
  static SsdpResponse parseResponse(String data) {
    final headers = <String, String>{};

    final lines = data.split(RegExp(r'\r?\n'));
    for (final line in lines.skip(1)) {
      final colonIndex = line.indexOf(':');
      if (colonIndex < 1) continue;
      final key = line.substring(0, colonIndex).trim().toLowerCase();
      final value = line.substring(colonIndex + 1).trim();
      headers[key] = value;
    }

    return SsdpResponse(
      location: headers['location'],
      usn: headers['usn'],
      st: headers['st'],
      headers: headers,
    );
  }

  /// Extracts the device UUID from a USN string.
  ///
  /// USN format: `uuid:<uuid>::<device/service type>`
  /// Returns the `uuid:<uuid>` portion, or the full string if no `::` separator.
  /// Returns null if [usn] is null.
  static String? extractUuid(String? usn) {
    if (usn == null) return null;
    final separatorIndex = usn.indexOf('::');
    if (separatorIndex < 0) return usn;
    return usn.substring(0, separatorIndex);
  }
}
