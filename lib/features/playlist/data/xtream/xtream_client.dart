/// Minimal Xtream Codes API helper.
///
/// Xtream is a de-facto IPTV billing/portal standard. Providers give the user
/// three credentials — a base URL, username, password — and the service
/// exposes:
///   * `player_api.php` for JSON auth/metadata
///   * `get.php?username=&password=&type=m3u_plus` for the playlist URL
///   * `xmltv.php?username=&password=` for the EPG URL
///
/// This helper turns `(baseUrl, user, pass)` into the equivalent M3U + EPG
/// URLs that our existing playlist importer understands, so adding Xtream
/// support doesn't require a second storage/pipeline layer.
class XtreamClient {
  final String baseUrl;
  final String username;
  final String password;

  XtreamClient({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  /// Normalize the base URL to the expected `scheme://host[:port]` form,
  /// stripping any trailing slash or accidental `/player_api.php` suffix.
  String get _normalizedBase {
    var url = baseUrl.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (url.endsWith('/player_api.php')) url = url.substring(0, url.length - '/player_api.php'.length);
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    return url;
  }

  /// URL to `get.php` serving the generated M3U playlist.
  String get m3uUrl =>
      '$_normalizedBase/get.php?username=${Uri.encodeQueryComponent(username)}&password=${Uri.encodeQueryComponent(password)}&type=m3u_plus&output=ts';

  /// URL to the XMLTV EPG.
  String get epgUrl =>
      '$_normalizedBase/xmltv.php?username=${Uri.encodeQueryComponent(username)}&password=${Uri.encodeQueryComponent(password)}';

  /// Auth endpoint; returns JSON including user/server info. Callers can GET
  /// this to validate credentials before importing the playlist.
  String get authUrl =>
      '$_normalizedBase/player_api.php?username=${Uri.encodeQueryComponent(username)}&password=${Uri.encodeQueryComponent(password)}';
}
