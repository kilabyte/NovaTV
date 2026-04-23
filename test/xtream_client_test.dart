import 'package:flutter_test/flutter_test.dart';
import 'package:novaiptv/features/playlist/data/xtream/xtream_client.dart';

void main() {
  group('XtreamClient', () {
    test('builds M3U and EPG URLs from bare host', () {
      final client = XtreamClient(
        baseUrl: 'provider.example.com:8080',
        username: 'alice',
        password: 'p@ss/word',
      );
      expect(
        client.m3uUrl,
        'http://provider.example.com:8080/get.php'
        '?username=alice&password=p%40ss%2Fword&type=m3u_plus&output=ts',
      );
      expect(
        client.epgUrl,
        'http://provider.example.com:8080/xmltv.php'
        '?username=alice&password=p%40ss%2Fword',
      );
    });

    test('preserves explicit https scheme', () {
      final client = XtreamClient(
        baseUrl: 'https://tv.example.com',
        username: 'u',
        password: 'p',
      );
      expect(client.authUrl.startsWith('https://tv.example.com/'), isTrue);
    });

    test('strips trailing slash and player_api.php suffix', () {
      final client = XtreamClient(
        baseUrl: 'http://tv.example.com/player_api.php',
        username: 'u',
        password: 'p',
      );
      expect(client.m3uUrl.startsWith('http://tv.example.com/get.php?'), isTrue);

      final client2 = XtreamClient(
        baseUrl: 'http://tv.example.com/',
        username: 'u',
        password: 'p',
      );
      expect(client2.m3uUrl.startsWith('http://tv.example.com/get.php?'), isTrue);
    });

    test('url-encodes special characters in credentials', () {
      final client = XtreamClient(
        baseUrl: 'http://x',
        username: 'a b&c',
        password: '1/2?3',
      );
      // Uri.encodeQueryComponent encodes space as '+' per application/x-
      // www-form-urlencoded rather than %20.
      expect(client.m3uUrl.contains('username=a+b%26c'), isTrue);
      expect(client.m3uUrl.contains('password=1%2F2%3F3'), isTrue);
    });
  });
}
