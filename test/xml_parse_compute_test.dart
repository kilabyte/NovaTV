import 'dart:convert';
import 'dart:io' show Directory, File, gzip;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novaiptv/features/epg/data/compute/xml_parse_compute.dart';

Map<String, dynamic> parseXmltv(String xml) {
  return parseXmltvContent(ParseXmltvParams(content: xml, sourceUrl: 'http://example.com/epg.xml'));
}

String programmeXml(String start, String stop) {
  return '<?xml version="1.0" encoding="UTF-8"?>'
      '<tv>'
      '<channel id="ch1"><display-name>Channel One</display-name></channel>'
      '<programme channel="ch1" start="$start" stop="$stop">'
      '<title>Show</title>'
      '</programme>'
      '</tv>';
}

void main() {
  group('XMLTV timezone offsets (MEDIUM-6)', () {
    test('offset without space separator matches the spaced form', () {
      final spaced = parseXmltv(programmeXml('20260611120000 +0100', '20260611130000 +0100'));
      final unspaced = parseXmltv(programmeXml('20260611120000+0100', '20260611130000+0100'));

      final spacedProgram = (spaced['programs'] as List).single as Map<String, dynamic>;
      final unspacedProgram = (unspaced['programs'] as List).single as Map<String, dynamic>;

      expect(unspacedProgram['start'], spacedProgram['start']);
      expect(unspacedProgram['end'], spacedProgram['end']);

      // +0100 means the stamp is one hour ahead of UTC: 12:00+0100 == 11:00Z.
      expect(spacedProgram['start'], DateTime.utc(2026, 6, 11, 11).millisecondsSinceEpoch);
    });

    test('negative offset without space is honored', () {
      final result = parseXmltv(programmeXml('20260611120000-0500', '20260611130000-0500'));
      final program = (result['programs'] as List).single as Map<String, dynamic>;
      expect(program['start'], DateTime.utc(2026, 6, 11, 17).millisecondsSinceEpoch);
    });

    test('offset-less stamps are still treated as UTC', () {
      final result = parseXmltv(programmeXml('20260611120000', '20260611130000'));
      final program = (result['programs'] as List).single as Map<String, dynamic>;
      expect(program['start'], DateTime.utc(2026, 6, 11, 12).millisecondsSinceEpoch);
    });
  });

  group('decodeXmltvBytes charset handling (MEDIUM-9, HIGH-2)', () {
    test('decodes a declared ISO-8859-1 feed with accented characters', () {
      const xml = '<?xml version="1.0" encoding="ISO-8859-1"?><tv>'
          '<channel id="fr1"><display-name>Télévision Française</display-name></channel>'
          '</tv>';
      final bytes = Uint8List.fromList(latin1.encode(xml));

      final decoded = decodeXmltvBytes(bytes);
      expect(decoded, contains('Télévision Française'));

      final parsed = parseXmltvContent(ParseXmltvParams(bytes: bytes, sourceUrl: 'http://example.com/epg.xml'));
      final channel = (parsed['channels'] as List).single as Map<String, dynamic>;
      expect(channel['displayName'], 'Télévision Française');
    });

    test('tolerates stray invalid bytes in an undeclared (UTF-8) feed', () {
      const xml = '<?xml version="1.0"?><tv></tv>';
      final bytes = Uint8List.fromList([...utf8.encode(xml.substring(0, 21)), 0xFF, ...utf8.encode(xml.substring(21))]);

      // Strict UTF-8 decode would throw FormatException here; the parser must
      // not discard the whole guide over one bad byte.
      expect(() => decodeXmltvBytes(bytes), returnsNormally);
    });

    test('decompresses gzipped bytes inside the decoder', () {
      const xml = '<?xml version="1.0" encoding="UTF-8"?><tv></tv>';
      final compressed = Uint8List.fromList(gzip.encode(utf8.encode(xml)));
      expect(decodeXmltvBytes(compressed), contains('<tv>'));
    });
  });

  group('parseXmltvContent file-path input (streamed downloads)', () {
    test('reads, gunzips and decodes a gzipped latin-1 feed from disk', () async {
      const xml = '<?xml version="1.0" encoding="ISO-8859-1"?><tv>'
          '<channel id="fr1"><display-name>Télévision Française</display-name></channel>'
          '<programme channel="fr1" start="20260611120000 +0000" stop="20260611130000 +0000">'
          '<title>Météo</title>'
          '</programme>'
          '</tv>';
      final dir = await Directory.systemTemp.createTemp('novatv_xmltv_test_');
      final file = File('${dir.path}/epg.xml.gz');
      await file.writeAsBytes(gzip.encode(latin1.encode(xml)));

      try {
        final parsed = parseXmltvContent(ParseXmltvParams(filePath: file.path, sourceUrl: 'http://example.com/epg.xml.gz'));
        final channel = (parsed['channels'] as List).single as Map<String, dynamic>;
        final program = (parsed['programs'] as List).single as Map<String, dynamic>;
        expect(channel['displayName'], 'Télévision Française');
        expect(program['title'], 'Météo');
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('file path and bytes inputs produce the same result', () async {
      const xml = '<?xml version="1.0" encoding="UTF-8"?><tv>'
          '<channel id="ch1"><display-name>One</display-name></channel>'
          '</tv>';
      final bytes = Uint8List.fromList(utf8.encode(xml));
      final dir = await Directory.systemTemp.createTemp('novatv_xmltv_test_');
      final file = File('${dir.path}/epg.xml');
      await file.writeAsBytes(bytes);

      try {
        final fromFile = parseXmltvContent(ParseXmltvParams(filePath: file.path, sourceUrl: 'http://example.com/epg.xml'));
        final fromBytes = parseXmltvContent(ParseXmltvParams(bytes: bytes, sourceUrl: 'http://example.com/epg.xml'));
        expect(fromFile['channels'], fromBytes['channels']);
        expect(fromFile['programs'], fromBytes['programs']);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
