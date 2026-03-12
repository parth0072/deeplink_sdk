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

  Future<DeeplinkData?> fetchInitData() async {
    try {
      final result = await _request<DeeplinkData?>(
        'POST',
        '/sdk/init',
        body: {
          'api_key': apiKey,
          ..._deviceSignals(),
        },
        parse: (json) {
          final map = json as Map<String, dynamic>;
          if (map['matched'] != true) return null;
          return DeeplinkData.fromJson(map);
        },
      );
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Collects device signals for improved probabilistic fingerprint matching.
  Map<String, String> _deviceSignals() {
    try {
      final signals = <String, String>{};
      if (Platform.isIOS || Platform.isAndroid) {
        // OS version: extract numeric part from "Version 17.2.1 (Build 21C52)" or "14"
        final raw = Platform.operatingSystemVersion;
        final match = RegExp(r'\d+[\d.]*').firstMatch(raw);
        if (match != null) signals['os_version'] = match.group(0)!;

        // Language (e.g. "en" from "en_US")
        signals['language'] = Platform.localeName.split(RegExp(r'[_\-]')).first;

        // Timezone as UTC offset string (e.g. "UTC-05:00")
        final offset = DateTime.now().timeZoneOffset;
        final h = offset.inHours.abs().toString().padLeft(2, '0');
        final m = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
        signals['timezone'] = 'UTC${offset.isNegative ? '-' : '+'}$h:$m';
      }
      return signals;
    } catch (_) {
      return {};
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

  /// Record an impression for a link displayed in-app. Fire-and-forget.
  /// Opening the link URL already auto-records an impression; call this only
  /// when you show a link inside a banner or share sheet without the user opening it.
  Future<void> recordImpression({required String alias}) async {
    try {
      await _request<void>(
        'POST',
        '/api/impressions',
        body: {
          'api_key': apiKey,
          'link_alias': alias,
          'platform': 'flutter',
        },
      );
    } catch (_) {
      // Fire-and-forget — swallow errors silently
    }
  }
}
