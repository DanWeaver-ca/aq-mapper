import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aq_mapping_app/models/measurement.dart';
import 'package:aq_mapping_app/services/upload_service.dart';

Measurement _m(int i) => Measurement(
      uid: 'TEST-$i',
      timestamp: DateTime(2026, 7, 24, 10, i),
      latitude: 43.7841,
      longitude: -79.1873,
      pm25: 8.0 + i,
      groupName: 'Group 7',
      deviceId: 'UTSC-AQMS-07',
      isIndoor: false,
    );

void main() {
  const endpoint = 'https://script.example/exec';

  test('posts all rows as text/plain JSON and parses the server reply',
      () async {
    late http.Request seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response(
          jsonEncode({'ok': true, 'received': 2, 'added': 1, 'total': 40}),
          200);
    });
    final service = UploadService(client: client, endpoint: endpoint);

    final result = await service.sendAll([_m(1), _m(2)],
        groupName: 'Group 7', deviceId: 'UTSC-AQMS-07');

    expect(result.received, 2);
    expect(result.added, 1);
    expect(result.total, 40);

    expect(seen.headers['Content-Type'], startsWith('text/plain'));
    final body = jsonDecode(seen.body) as Map<String, dynamic>;
    expect(body['group'], 'Group 7');
    expect(body['device'], 'UTSC-AQMS-07');
    final rows = body['rows'] as List;
    expect(rows, hasLength(2));
    // Every row must match the CSV contract exactly — the sheet's columns
    // are the same file format Home Base reads.
    expect((rows.first as List), hasLength(Measurement.csvHeaders.length));
    final uidIndex = Measurement.csvHeaders.indexOf('UID');
    expect((rows.first as List)[uidIndex], 'TEST-1');
  });

  test('follows the Apps Script POST redirect with a GET', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add(request.method);
      if (request.method == 'POST') {
        return http.Response('', 302,
            headers: {'location': 'https://script.example/result'});
      }
      expect(request.url.toString(), 'https://script.example/result');
      return http.Response(
          jsonEncode({'ok': true, 'received': 1, 'added': 1, 'total': 1}),
          200);
    });
    final service = UploadService(client: client, endpoint: endpoint);

    final result = await service.sendAll([_m(1)]);

    expect(calls, ['POST', 'GET']);
    expect(result.added, 1);
  });

  test('surfaces a server-side rejection as an UploadException', () {
    final client = MockClient((request) async => http.Response(
        jsonEncode({'ok': false, 'error': 'row 0 malformed'}), 200));
    final service = UploadService(client: client, endpoint: endpoint);

    expect(
        () => service.sendAll([_m(1)]),
        throwsA(isA<UploadException>().having(
            (e) => e.message, 'message', contains('row 0 malformed'))));
  });

  test('surfaces an HTTP error status as an UploadException', () {
    final client =
        MockClient((request) async => http.Response('oops', 500));
    final service = UploadService(client: client, endpoint: endpoint);

    expect(
        () => service.sendAll([_m(1)]),
        throwsA(isA<UploadException>()
            .having((e) => e.message, 'message', contains('500'))));
  });

  test('rejects a non-JSON reply instead of pretending success', () {
    final client = MockClient(
        (request) async => http.Response('<html>sign in</html>', 200));
    final service = UploadService(client: client, endpoint: endpoint);

    expect(() => service.sendAll([_m(1)]), throwsA(isA<UploadException>()));
  });

  test('is unconfigured (and throws) when no endpoint is set', () {
    final client = MockClient((request) async => http.Response('', 200));
    final service = UploadService(client: client, endpoint: '');

    expect(service.isConfigured, isFalse);
    expect(() => service.sendAll([_m(1)]), throwsA(isA<UploadException>()));
  });
}
