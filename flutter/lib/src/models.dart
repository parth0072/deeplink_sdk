/// Data returned by [Deeplink.getInitData] when the app is opened via a deep link.
class DeeplinkData {
  final String? destinationUrl;
  final String? iosUrl;
  final String? androidUrl;
  final String? alias;
  final Map<String, dynamic> metadata;

  const DeeplinkData({
    this.destinationUrl,
    this.iosUrl,
    this.androidUrl,
    this.alias,
    this.metadata = const {},
  });

  factory DeeplinkData.fromJson(Map<String, dynamic> json) {
    final link = json['link'] as Map<String, dynamic>? ?? json;
    return DeeplinkData(
      destinationUrl: link['destination_url'] as String?,
      iosUrl: link['ios_url'] as String?,
      androidUrl: link['android_url'] as String?,
      alias: link['alias'] as String?,
      metadata: (link['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }
}

/// A parsed incoming deep link URL.
class IncomingLink {
  final Uri uri;
  final List<String> pathSegments;
  final Map<String, String> params;

  const IncomingLink({
    required this.uri,
    required this.pathSegments,
    required this.params,
  });

  factory IncomingLink.fromUri(Uri uri) => IncomingLink(
        uri: uri,
        pathSegments: uri.pathSegments,
        params: uri.queryParameters,
      );
}

/// Result of [Deeplink.createLink].
class CreatedLink {
  final String id;
  final String url;
  final String alias;

  const CreatedLink({
    required this.id,
    required this.url,
    required this.alias,
  });

  factory CreatedLink.fromJson(Map<String, dynamic> json) => CreatedLink(
        id: json['id'] as String,
        url: json['url'] as String,
        alias: json['alias'] as String,
      );
}
