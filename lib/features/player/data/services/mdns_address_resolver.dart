import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

/// Resolves an mDNS/Bonjour host (e.g. `Chromecast-abc.local`) to a numeric
/// IP address.
///
/// Why this exists: Apple's DNS-SD resolve (used by bonsoir on macOS/iOS) hands
/// back a `.local` hostname, not an IP. Dart's [InternetAddress.lookup] does
/// NOT resolve `.local` names — it never routes mDNS, so it just times out
/// (verified on macOS, even unsandboxed). The system C `getaddrinfo`, however,
/// resolves `.local` instantly via mDNSResponder, and works inside the App
/// Sandbox with `com.apple.security.network.client`. So on Apple platforms we
/// call `getaddrinfo` directly through FFI; elsewhere we fall back to the Dart
/// resolver (Android already returns IPs from NsdManager).
Future<InternetAddress?> resolveHostToIp(String host) async {
  final direct = InternetAddress.tryParse(host);
  if (direct != null) return direct;

  // getaddrinfo wants the bare name; mDNS names sometimes carry a trailing dot.
  final cleaned = host.endsWith('.') ? host.substring(0, host.length - 1) : host;

  if (Platform.isMacOS || Platform.isIOS) {
    try {
      // getaddrinfo is blocking; run it off the UI isolate. A slow/failed
      // resolve can't be cancelled, but it returns quickly for reachable
      // mDNS hosts; on timeout we just move on (the orphaned isolate ends).
      final ip = await Isolate.run(() => _sysResolveIPv4(cleaned))
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (ip != null) {
        final addr = InternetAddress.tryParse(ip);
        if (addr != null) return addr;
      }
    } catch (_) {
      // Fall through to the Dart resolver.
    }
  }

  try {
    final results = await InternetAddress.lookup(cleaned)
        .timeout(const Duration(seconds: 4));
    for (final a in results) {
      if (a.type == InternetAddressType.IPv4) return a;
    }
    return results.isNotEmpty ? results.first : null;
  } catch (_) {
    return null;
  }
}

// AF_INET / SOCK_STREAM on Apple platforms.
const int _afInet = 2;
const int _sockStream = 1;

/// Synchronous IPv4 resolution via the system `getaddrinfo` (Apple/BSD struct
/// layout). Returns a dotted-quad string, or null. Runs in a background
/// isolate via [Isolate.run].
///
/// BSD `struct addrinfo` (64-bit): ai_flags(4) ai_family(4) ai_socktype(4)
/// ai_protocol(4) ai_addrlen(4) +pad(4) ai_canonname(ptr@24) ai_addr(ptr@32)
/// ai_next(ptr@40). For AF_INET, ai_addr points at `struct sockaddr_in` whose
/// 4 IPv4 bytes sit at offset 4 (after sin_len, sin_family, sin_port).
String? _sysResolveIPv4(String host) {
  final lib = DynamicLibrary.process();
  final getaddrinfo = lib.lookupFunction<
      Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Uint8>,
          Pointer<Pointer<Uint8>>),
      int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Uint8>,
          Pointer<Pointer<Uint8>>)>('getaddrinfo');
  final freeaddrinfo = lib.lookupFunction<Void Function(Pointer<Uint8>),
      void Function(Pointer<Uint8>)>('freeaddrinfo');

  final node = host.toNativeUtf8();
  final hints = calloc<Uint8>(48); // sizeof(struct addrinfo)
  Pointer<Int32>.fromAddress(hints.address + 4).value = _afInet; // ai_family
  Pointer<Int32>.fromAddress(hints.address + 8).value = _sockStream; // ai_socktype
  final resPtr = calloc<Pointer<Uint8>>();

  try {
    final rc = getaddrinfo(node, nullptr, hints, resPtr);
    if (rc != 0) return null;

    var ai = resPtr.value;
    while (ai != nullptr) {
      final family = Pointer<Int32>.fromAddress(ai.address + 4).value;
      final sockAddrInt = Pointer<IntPtr>.fromAddress(ai.address + 32).value;
      if (family == _afInet && sockAddrInt != 0) {
        final sa = Pointer<Uint8>.fromAddress(sockAddrInt);
        return '${sa[4]}.${sa[5]}.${sa[6]}.${sa[7]}';
      }
      ai = Pointer<Uint8>.fromAddress(
          Pointer<IntPtr>.fromAddress(ai.address + 40).value); // ai_next
    }
    return null;
  } finally {
    if (resPtr.value != nullptr) freeaddrinfo(resPtr.value);
    calloc.free(node);
    calloc.free(hints);
    calloc.free(resPtr);
  }
}
