/// Data returned by [Deeplink.getInitData] when the app is opened via a deep link.
class DeeplinkData {
  final String linkId;
  final String alias;
  final String destinationUrl;
  final String? iosUrl;
  final String? androidUrl;
  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final String? utmContent;
  final String? utmTerm;
  /// Custom key-value metadata set on the link in the dashboard.
  final Map<String, dynamic> metadata;
  /// Creative name for attribution reporting.
  final String? creativeName;
  /// Creative ID for attribution reporting.
  final String? creativeId;

  const DeeplinkData({
    required this.linkId,
    required this.alias,
    required this.destinationUrl,
    this.iosUrl,
    this.androidUrl,
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.utmContent,
    this.utmTerm,
    this.metadata = const {},
    this.creativeName,
    this.creativeId,
  });

  factory DeeplinkData.fromJson(Map<String, dynamic> json) {
    // /sdk/init returns { matched: true, data: { linkId, alias, ... } }
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return DeeplinkData(
      linkId:         data['linkId'] as String? ?? '',
      alias:          data['alias']  as String? ?? '',
      destinationUrl: data['destinationUrl'] as String? ?? '',
      iosUrl:         data['iosUrl'] as String?,
      androidUrl:     data['androidUrl'] as String?,
      utmSource:      data['utmSource'] as String?,
      utmMedium:      data['utmMedium'] as String?,
      utmCampaign:    data['utmCampaign'] as String?,
      utmContent:     data['utmContent'] as String?,
      utmTerm:        data['utmTerm'] as String?,
      metadata:       (data['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
      creativeName:   data['creativeName'] as String?,
      creativeId:     data['creativeId'] as String?,
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
  final String linkId;
  final String url;
  final String alias;

  const CreatedLink({
    required this.linkId,
    required this.url,
    required this.alias,
  });

  factory CreatedLink.fromJson(Map<String, dynamic> json) => CreatedLink(
        linkId: json['link_id'] as String? ?? json['id'] as String? ?? '',
        url:    json['url']     as String,
        alias:  json['alias']   as String,
      );
}
