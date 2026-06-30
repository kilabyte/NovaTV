import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:dart_cast/dart_cast.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import '../../../../core/utils/app_logger.dart';
import 'mdns_address_resolver.dart';

/// Discovers Chromecast devices via native Bonjour (the `bonsoir` plugin)
/// instead of dart_cast's default raw-multicast `multicast_dns` provider.
///
/// Why: dart_cast's [ChromecastDiscoveryProvider] opens its own UDP multicast
/// socket. Under the macOS App Sandbox (and on iOS) that requires Apple's
/// special-approval `com.apple.developer.networking.multicast` entitlement,
/// which would block the App Store build until Apple grants it. bonsoir wraps
/// the system Bonjour browser (NSNetServiceBrowser / NsdManager / Avahi /
/// Win32 DNS-SD), so the only platform requirements are the standard
/// `NSLocalNetworkUsageDescription` + `NSBonjourServices` Info.plist keys on
/// Apple and the Wi-Fi/multicast permissions on Android — no special
/// entitlement. bonsoir supports all five native platforms, so this is the
/// single discovery path everywhere.
class BonsoirChromecastDiscoveryProvider implements DeviceDiscoveryProvider {
  /// Bonjour service type for Chromecast. Note: bonsoir wants the bare type
  /// (`_googlecast._tcp`), not the `.local`-suffixed form mDNS uses.
  static const String _serviceType = '_googlecast._tcp';

  BonsoirDiscovery? _discovery;
  StreamController<List<CastDevice>>? _controller;
  StreamSubscription<BonsoirDiscoveryEvent>? _subscription;
  Timer? _timeoutTimer;

  /// Resolved devices keyed by their stable mDNS instance name. Keyed by name
  /// rather than the Chromecast TXT `id` because "service lost" events do not
  /// always carry resolved TXT records, but the instance name is always
  /// present.
  final Map<String, CastDevice> _devices = {};

  @override
  CastProtocol get protocol => CastProtocol.chromecast;

  @override
  Stream<List<CastDevice>> startDiscovery({
    Duration timeout = const Duration(seconds: 10),
  }) {
    stopDiscovery();
    _devices.clear();
    final controller = StreamController<List<CastDevice>>();
    _controller = controller;
    // Kick off async discovery without blocking the synchronous stream return.
    unawaited(_run(timeout, controller));
    return controller.stream;
  }

  Future<void> _run(
    Duration timeout,
    StreamController<List<CastDevice>> controller,
  ) async {
    try {
      final discovery = BonsoirDiscovery(type: _serviceType, printLogs: kDebugMode);
      _discovery = discovery;
      await discovery.initialize();

      _subscription = discovery.eventStream?.listen(
        (event) => _onEvent(discovery, event, controller),
        onError: (Object error) {
          AppLogger.warning('Chromecast Bonjour discovery error: $error');
        },
      );

      await discovery.start();
      AppLogger.info('Cast: Bonjour discovery started for $_serviceType');

      // Bonjour browsing runs continuously; cap it to the requested window so
      // the stream completes and the caller's "discovering" spinner stops.
      _timeoutTimer = Timer(timeout, stopDiscovery);
    } catch (e) {
      AppLogger.warning('Chromecast Bonjour discovery failed to start: $e');
      if (!controller.isClosed) {
        controller.addError(e);
        await controller.close();
      }
    }
  }

  void _onEvent(
    BonsoirDiscovery discovery,
    BonsoirDiscoveryEvent event,
    StreamController<List<CastDevice>> controller,
  ) {
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent():
        // A service appeared but isn't resolved yet (no host/port). Ask the
        // platform to resolve it; a ServiceResolved event follows. Some
        // platforms hand us an already-resolved service, in which case add it
        // directly (resolve() would be a no-op and emit no further event).
        AppLogger.debug('Cast/Bonjour: service found "${event.service.name}" '
            '(host=${event.service.host})');
        if (event.service.host != null) {
          _addResolved(event.service, controller);
        } else {
          unawaited(_resolve(discovery, event.service));
        }
      case BonsoirDiscoveryServiceResolvedEvent():
        AppLogger.debug('Cast/Bonjour: service resolved "${event.service.name}" '
            'host=${event.service.host} port=${event.service.port}');
        _addResolved(event.service, controller);
      case BonsoirDiscoveryServiceLostEvent():
        if (_devices.remove(event.service.name) != null &&
            !controller.isClosed) {
          controller.add(_devices.values.toList());
        }
      case BonsoirDiscoveryServiceResolveFailedEvent():
        AppLogger.warning('Cast/Bonjour: a discovered service failed to resolve');
      case BonsoirDiscoveryStartedEvent():
        AppLogger.debug('Cast/Bonjour: browse started');
      case BonsoirDiscoveryStoppedEvent():
        AppLogger.debug('Cast/Bonjour: browse stopped');
      default:
        break;
    }
  }

  Future<void> _resolve(
    BonsoirDiscovery discovery,
    BonsoirService service,
  ) async {
    try {
      await service.resolve(discovery.serviceResolver);
    } catch (e) {
      AppLogger.debug('Chromecast Bonjour resolve failed for '
          '"${service.name}": $e');
    }
  }

  Future<void> _addResolved(
    BonsoirService service,
    StreamController<List<CastDevice>> controller,
  ) async {
    final device = await _toCastDevice(service);
    if (device == null) {
      AppLogger.warning('Cast/Bonjour: dropped "${service.name}" — could not '
          'resolve an IP from host=${service.host} port=${service.port}');
      return;
    }
    if (controller.isClosed) return;
    _devices[service.name] = device;
    AppLogger.info('Cast: discovered "${device.name}" at '
        '${device.address.address}:${device.port}');
    controller.add(_devices.values.toList());
  }

  Future<CastDevice?> _toCastDevice(BonsoirService service) async {
    final host = service.host;
    if (host == null) return null;
    final address = await _resolveAddress(host);
    if (address == null) return null;

    final attrs = service.attributes;
    // Chromecast advertises `id` (device uuid) and `fn` (friendly name) in its
    // TXT records; fall back to the instance name if absent.
    final id = attrs['id']?.isNotEmpty == true
        ? attrs['id']!
        : '${service.name}:${service.port}';
    final name = attrs['fn']?.isNotEmpty == true
        ? attrs['fn']!
        : _friendlyName(service.name);

    return CastDevice(
      id: id,
      name: name,
      protocol: CastProtocol.chromecast,
      address: address,
      port: service.port,
      metadata: attrs,
    );
  }

  /// [CastDevice.address] is an [InternetAddress], which only accepts a numeric
  /// IP. bonsoir usually resolves [BonsoirService.host] to an IP, but some
  /// platforms return an mDNS hostname (e.g. `Chromecast-abc.local`); resolve
  /// those via the system resolver, preferring IPv4.
  /// [CastDevice.address] needs a numeric IP. bonsoir hands back a `.local`
  /// mDNS hostname on Apple platforms, which Dart's resolver cannot resolve;
  /// [resolveHostToIp] uses the system resolver (getaddrinfo) for those.
  Future<InternetAddress?> _resolveAddress(String host) => resolveHostToIp(host);

  /// Strip any trailing mDNS service/domain suffix from an instance name.
  String _friendlyName(String name) {
    final dotIndex = name.indexOf('._');
    return dotIndex > 0 ? name.substring(0, dotIndex) : name;
  }

  @override
  void stopDiscovery() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _subscription?.cancel();
    _subscription = null;
    final discovery = _discovery;
    _discovery = null;
    if (discovery != null && !discovery.isStopped) {
      // Fire-and-forget; nothing actionable if the platform stop fails.
      unawaited(discovery.stop().catchError((Object _) {}));
    }
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      unawaited(controller.close());
    }
  }

  @override
  void dispose() {
    stopDiscovery();
  }
}
