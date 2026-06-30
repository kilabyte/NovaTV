import 'dart:async';
import 'dart:io';

import '../../core/cast_device.dart';
import '../../core/discovery_provider.dart';
import '../../utils/logger.dart';
import 'dlna_device.dart';
import 'ssdp_discovery.dart';

/// Function type for creating a UDP socket for SSDP discovery.
typedef RawDatagramSocketFactory =
    Future<RawDatagramSocket> Function(dynamic host, int port);

/// Function type for fetching a URL and returning its body.
typedef HttpFetcher = Future<String> Function(String url);

/// Discovers DLNA (UPnP) media renderers via SSDP M-SEARCH.
///
/// Sends multicast M-SEARCH queries for AVTransport and MediaRenderer
/// services, parses responses, fetches device description XML, and
/// emits [CastDevice] lists as devices are found.
class DlnaDiscoveryProvider implements DeviceDiscoveryProvider {
  final RawDatagramSocketFactory _socketFactory;
  final HttpFetcher _httpFetcher;

  RawDatagramSocket? _socket;
  StreamController<List<CastDevice>>? _controller;
  Timer? _searchTimer;
  final Map<String, CastDevice> _devices = {};

  /// Creates a [DlnaDiscoveryProvider].
  ///
  /// Optional [socketFactory] and [httpFetcher] can be provided for testing.
  DlnaDiscoveryProvider({
    RawDatagramSocketFactory? socketFactory,
    HttpFetcher? httpFetcher,
  }) : _socketFactory = socketFactory ?? RawDatagramSocket.bind,
       _httpFetcher = httpFetcher ?? _defaultHttpFetch;

  @override
  CastProtocol get protocol => CastProtocol.dlna;

  @override
  Stream<List<CastDevice>> startDiscovery({
    Duration timeout = const Duration(seconds: 10),
  }) {
    stopDiscovery();
    _devices.clear();
    _controller = StreamController<List<CastDevice>>();

    _doDiscovery(timeout);

    return _controller!.stream;
  }

  Future<void> _doDiscovery(Duration timeout) async {
    try {
      CastLogger.info('DLNA: binding UDP socket for SSDP discovery');
      _socket = await _socketFactory(InternetAddress.anyIPv4, 0);
      _socket!.broadcastEnabled = true;
      _socket!.multicastLoopback = false;

      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _handleResponse(String.fromCharCodes(datagram.data));
          }
        }
      });

      // Send M-SEARCH for MediaRenderer
      final searchTarget = SsdpConstants.searchTargets[2]; // MediaRenderer
      final mSearch = SsdpMessage.mSearch(searchTarget, 3);
      final data = mSearch.codeUnits;
      final address = InternetAddress(SsdpConstants.multicastAddress);

      CastLogger.info(
        'DLNA: sending M-SEARCH to ${SsdpConstants.multicastAddress}:${SsdpConstants.multicastPort}',
      );
      _socket!.send(data, address, SsdpConstants.multicastPort);

      // Send again after a short delay for reliability
      _searchTimer = Timer(const Duration(milliseconds: 500), () {
        try {
          _socket?.send(data, address, SsdpConstants.multicastPort);
        } catch (_) {}
      });

      // Close after timeout
      Timer(timeout, () {
        CastLogger.info('DLNA: discovery timeout reached, closing');
        _controller?.close();
      });
    } catch (e) {
      CastLogger.error('DLNA: discovery failed: $e');
      _controller?.addError(e);
      _controller?.close();
    }
  }

  void _handleResponse(String data) async {
    final response = SsdpMessage.parseResponse(data);
    final location = response.location;
    if (location == null) return;

    final uuid = SsdpMessage.extractUuid(response.usn);
    if (uuid == null) return;

    // Skip if we already have this device
    if (_devices.containsKey(uuid)) return;

    CastLogger.debug(
      'DLNA: SSDP response from $uuid, fetching description at $location',
    );

    try {
      final xml = await _httpFetcher(location);
      final description = DlnaDeviceDescription.parse(xml, location);
      final device = description.toCastDevice();
      CastLogger.info(
        'DLNA: found device "${device.name}" at ${device.address.address}:${device.port}',
      );
      _devices[uuid] = device;

      if (_controller?.isClosed == false) {
        _controller!.add(_devices.values.toList());
      }
    } catch (e) {
      CastLogger.warning(
        'DLNA: failed to fetch description for $uuid at $location: $e',
      );
    }
  }

  @override
  void stopDiscovery() {
    _searchTimer?.cancel();
    _searchTimer = null;
    _socket?.close();
    _socket = null;
    if (_controller?.isClosed == false) {
      _controller?.close();
    }
    _controller = null;
  }

  @override
  void dispose() {
    stopDiscovery();
  }

  static Future<String> _defaultHttpFetch(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final body =
          await response.transform(const SystemEncoding().decoder).join();
      return body;
    } finally {
      client.close();
    }
  }
}
