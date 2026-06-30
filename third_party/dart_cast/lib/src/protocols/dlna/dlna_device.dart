import 'dart:io';

import '../../core/cast_device.dart';

/// Parsed DLNA device description with extracted service control URLs.
class DlnaDeviceDescription {
  /// Human-readable device name.
  final String friendlyName;

  /// Device manufacturer.
  final String? manufacturer;

  /// Device model name.
  final String? modelName;

  /// Universally unique device name (e.g., `uuid:xxxx-xxxx-...`).
  final String udn;

  /// Absolute URL for AVTransport SOAP control.
  final String? avTransportControlUrl;

  /// Absolute URL for RenderingControl SOAP control.
  final String? renderingControlUrl;

  /// Absolute URL for ConnectionManager SOAP control.
  final String? connectionManagerControlUrl;

  /// The location URL this description was fetched from.
  final String locationUrl;

  DlnaDeviceDescription({
    required this.friendlyName,
    this.manufacturer,
    this.modelName,
    required this.udn,
    this.avTransportControlUrl,
    this.renderingControlUrl,
    this.connectionManagerControlUrl,
    required this.locationUrl,
  });

  /// Parses a device description [xml] fetched from [locationUrl].
  ///
  /// Extracts device metadata and resolves service control URLs against
  /// the `<URLBase>` element (if present) or the [locationUrl] origin.
  factory DlnaDeviceDescription.parse(String xml, String locationUrl) {
    final friendlyName = _extractElement(xml, 'friendlyName') ?? 'Unknown';
    final manufacturer = _extractElement(xml, 'manufacturer');
    final modelName = _extractElement(xml, 'modelName');
    final udn = _extractElement(xml, 'UDN') ?? '';

    // Determine base URL: prefer URLBase, fall back to location origin.
    final urlBase = _extractElement(xml, 'URLBase');
    final baseUri =
        urlBase != null ? Uri.parse(urlBase) : _originFromUrl(locationUrl);

    // Extract service control URLs.
    String? avTransportControlUrl;
    String? renderingControlUrl;
    String? connectionManagerControlUrl;

    final serviceBlocks = RegExp(
      r'<service>([\s\S]*?)</service>',
      caseSensitive: false,
    ).allMatches(xml);

    for (final match in serviceBlocks) {
      final block = match.group(1)!;
      final serviceType = _extractElement(block, 'serviceType');
      final controlUrl = _extractElement(block, 'controlURL');

      if (serviceType == null || controlUrl == null) continue;

      final resolvedUrl = _resolveUrl(baseUri, controlUrl);

      if (serviceType.contains('AVTransport')) {
        avTransportControlUrl = resolvedUrl;
      } else if (serviceType.contains('RenderingControl')) {
        renderingControlUrl = resolvedUrl;
      } else if (serviceType.contains('ConnectionManager')) {
        connectionManagerControlUrl = resolvedUrl;
      }
    }

    return DlnaDeviceDescription(
      friendlyName: friendlyName,
      manufacturer: manufacturer,
      modelName: modelName,
      udn: udn,
      avTransportControlUrl: avTransportControlUrl,
      renderingControlUrl: renderingControlUrl,
      connectionManagerControlUrl: connectionManagerControlUrl,
      locationUrl: locationUrl,
    );
  }

  /// Creates a [CastDevice] from this device description.
  CastDevice toCastDevice() {
    final uri = Uri.parse(locationUrl);

    final metadata = <String, String>{};
    if (avTransportControlUrl != null) {
      metadata['avTransportControlUrl'] = avTransportControlUrl!;
    }
    if (renderingControlUrl != null) {
      metadata['renderingControlUrl'] = renderingControlUrl!;
    }
    if (connectionManagerControlUrl != null) {
      metadata['connectionManagerControlUrl'] = connectionManagerControlUrl!;
    }
    if (manufacturer != null) {
      metadata['manufacturer'] = manufacturer!;
    }
    if (modelName != null) {
      metadata['modelName'] = modelName!;
    }

    return CastDevice(
      id: udn,
      name: friendlyName,
      protocol: CastProtocol.dlna,
      address: InternetAddress(uri.host),
      port: uri.port,
      metadata: metadata,
    );
  }

  /// Extracts the text content of an XML element using regex.
  static String? _extractElement(String xml, String element) {
    final match = RegExp(
      '<$element>([^<]*)</$element>',
      caseSensitive: true,
    ).firstMatch(xml);
    return match?.group(1)?.trim();
  }

  /// Extracts the origin (scheme + host + port) from a URL.
  static Uri _originFromUrl(String url) {
    final uri = Uri.parse(url);
    return Uri(scheme: uri.scheme, host: uri.host, port: uri.port);
  }

  /// Resolves a potentially relative [controlUrl] against a [baseUri].
  static String _resolveUrl(Uri baseUri, String controlUrl) {
    if (controlUrl.startsWith('http://') || controlUrl.startsWith('https://')) {
      return controlUrl;
    }
    return baseUri.resolve(controlUrl).toString();
  }
}
