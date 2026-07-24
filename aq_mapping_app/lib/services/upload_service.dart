import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../models/measurement.dart';

/// What the class endpoint reported back, so the UI can be honest about
/// what actually happened (mirrors SendOutcome's philosophy).
class UploadResult {
  /// Rows this request carried.
  final int received;

  /// Rows the server hadn't seen before (rest were already uploaded).
  final int added;

  /// Rows the class sheet holds in total, all groups combined.
  final int total;

  const UploadResult(
      {required this.received, required this.added, required this.total});
}

class UploadException implements Exception {
  final String message;
  const UploadException(this.message);
  @override
  String toString() => message;
}

/// "Send to class": POST every reading to the configured endpoint
/// ([uploadUrl], typically the Apps Script receiver in
/// classroom_map/upload_endpoint/). Feature is absent when no URL is
/// configured.
///
/// Sends ALL rows every time — the endpoint and Home Base both dedup by
/// UID, so re-sending is the safe default and needs no local bookkeeping
/// (and no DB schema change).
///
/// Content-Type is text/plain ON PURPOSE: it keeps the request "simple" so
/// browsers skip the CORS preflight that Apps Script cannot answer. This is
/// also why it works inside WeChat's in-app browser, where the share sheet
/// and file downloads do not.
class UploadService {
  UploadService({http.Client? client, String? endpoint})
      : _client = client ?? http.Client(),
        _endpoint = endpoint ?? uploadUrl;

  final http.Client _client;
  final String _endpoint;

  bool get isConfigured => _endpoint.isNotEmpty;

  Future<UploadResult> sendAll(
    List<Measurement> measurements, {
    String? groupName,
    String? deviceId,
  }) async {
    if (!isConfigured) {
      throw const UploadException('No class endpoint is configured.');
    }
    final body = jsonEncode({
      'version': 1,
      'group': groupName,
      'device': deviceId,
      'rows': [for (final m in measurements) m.toCsvRow()],
    });

    http.Response resp;
    try {
      resp = await _client
          .post(Uri.parse(_endpoint),
              headers: {'Content-Type': 'text/plain;charset=utf-8'},
              body: body)
          .timeout(const Duration(seconds: 30));
      // Apps Script answers a POST with a redirect to the JSON result. The
      // browser's fetch follows it transparently (web build), but dart:io
      // does not follow redirects for POST — finish the hop with a GET.
      final redirect = resp.headers['location'];
      if (resp.statusCode >= 301 && resp.statusCode <= 303 &&
          redirect != null) {
        resp = await _client
            .get(Uri.parse(redirect))
            .timeout(const Duration(seconds: 30));
      }
    } on TimeoutException {
      throw const UploadException(
          'The upload timed out — check your connection and try again.');
    } on http.ClientException {
      throw const UploadException(
          'Could not reach the class endpoint — check your connection.');
    }

    if (resp.statusCode != 200) {
      throw UploadException('Server error (HTTP ${resp.statusCode}).');
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(resp.body);
    } on FormatException {
      throw const UploadException('Unexpected reply from the endpoint.');
    }
    if (decoded is! Map || decoded['ok'] != true) {
      final err = decoded is Map ? decoded['error'] : null;
      throw UploadException('Upload rejected${err == null ? '' : ': $err'}.');
    }
    int asInt(dynamic v) => v is num ? v.toInt() : 0;
    return UploadResult(
      received: asInt(decoded['received']),
      added: asInt(decoded['added']),
      total: asInt(decoded['total']),
    );
  }
}
