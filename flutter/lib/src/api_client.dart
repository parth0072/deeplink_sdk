import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiClient {
  final String apiKey;
  final String baseUrl;

  const ApiClient({required this.apiKey, required this.baseUrl});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
      };

  Future<T> _request<T>(
    String method,
    String path, {
    Map<String, dynamic>? body,
    T Function(dynamic)? parse,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    http.Response res;

    switch (method) {
      case 'GET':
        res = await http.get(uri, headers: _headers);
      case 'POST':
        res = await http.post(uri, headers: _headers, body: jsonEncode(body));
      case 'DELETE':
        res = await http.delete(uri, headers: _headers);
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      String message;
      try {
        final json = jsonDecode(res.body) as Map;
        message = json['error']?.toString() ?? res.reasonPhrase ?? 'Unknown error';
      } catch (_) {
        message = res.reasonPhrase ?? 'Unknown error';
      }
      throw Exception('Deeplink API [${res.statusCode}]: $message');
    }

    if (res.body.isEmpty) return null as T;
    final json = jsonDecode(res.body);
    return parse != null ? parse(json) : json as T;
  }

  Future<DeeplinkData?> fetchInitData({
    required String? fingerprintHash,
    required String sessionId,
  }) async {
    try {
      final result = await _request<DeeplinkData>(
        'POST',
        '/sdk/init',
        body: {
          'api_key': apiKey,
          'fingerprint_hash': fingerprintHash,
          'session_id': sessionId,
          'platform': 'flutter',
        },
        parse: (json) => DeeplinkData.fromJson(json as Map<String, dynamic>),
      );
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<CreatedLink?> createLink({
    required String destinationUrl,
    String? iosUrl,
    String? androidUrl,
    String? alias,
    String? title,
    String? description,
    Map<String, String> params = const {},
    String? utmSource,
    String? utmMedium,
    String? utmCampaign,
    String? expiresAt,
  }) async {
    return _request<CreatedLink>(
      'POST',
      '/sdk/link',
      body: {
        'api_key': apiKey,
        'destination_url': destinationUrl,
        if (iosUrl != null) 'ios_url': iosUrl,
        if (androidUrl != null) 'android_url': androidUrl,
        if (alias != null) 'alias': alias,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        'metadata': params,
        if (utmSource != null) 'utm_source': utmSource,
        if (utmMedium != null) 'utm_medium': utmMedium,
        if (utmCampaign != null) 'utm_campaign': utmCampaign,
        if (expiresAt != null) 'expires_at': expiresAt,
      },
      parse: (json) => CreatedLink.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> trackEvent({
    required String name,
    required Map<String, dynamic> properties,
    required String sessionId,
  }) async {
    try {
      await _request<void>(
        'POST',
        '/api/events',
        body: {
          'api_key': apiKey,
          'name': name,
          'properties': properties,
          'session_id': sessionId,
        },
      );
    } catch (_) {
      // Event tracking is fire-and-forget — swallow errors silently
    }
  }
}
