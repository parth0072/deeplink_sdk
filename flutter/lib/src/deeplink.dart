import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'api_client.dart';
import 'models.dart';

/// Main entry point for the Deeplink SDK.
///
/// **Setup (main.dart):**
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Deeplink.configure(
///     apiKey: 'your-api-key',
///     domain: 'https://dl.yourapp.com',
///   );
///   runApp(const MyApp());
/// }
/// ```
///
/// **Deferred deep link (first launch):**
/// ```dart
/// final data = await Deeplink.getInitData();
/// if (data != null) {
///   // Navigate using data.iosUrl / data.androidUrl / data.metadata
/// }
/// ```
///
/// **Handle incoming deep link:**
/// ```dart
/// // In your router or onGenerateRoute:
/// final link = Deeplink.handleIncomingUri(uri);
/// if (link != null) { /* navigate */ }
/// ```
class Deeplink {
  static const _keyInitFetched = 'dl_init_fetched';
  static const _keySessionId   = 'dl_session_id';

  static ApiClient? _client;
  static String? _domain;

  Deeplink._();

  // ── Setup ────────────────────────────────────────────────────────────────

  /// Configure the SDK. Call once before any other SDK method, ideally in `main()`.
  static Future<void> configure({
    required String apiKey,
    required String domain,
  }) async {
    final base = domain.startsWith('http://') || domain.startsWith('https://')
        ? domain
        : 'https://$domain';
    _domain = base;
    _client = ApiClient(apiKey: apiKey, baseUrl: base);
  }

  // ── Deferred deep link ────────────────────────────────────────────────────

  /// Fetch deferred deep link data from the server.
  ///
  /// Returns [DeeplinkData] on a matched install, or `null` if no match or
  /// already fetched. Pass `force: true` to bypass the one-time guard.
  static Future<DeeplinkData?> getInitData({bool force = false}) async {
    _requireConfigured();
    final prefs = await SharedPreferences.getInstance();

    final alreadyFetched = prefs.getBool(_keyInitFetched) ?? false;
    if (alreadyFetched && !force) return null;

    final data = await _client!.fetchInitData();

    if (data != null) {
      await prefs.setBool(_keyInitFetched, true);
    }
    return data;
  }

  // ── Incoming link handling ────────────────────────────────────────────────

  /// Parse an incoming [Uri] (from app links, universal links, or custom schemes).
  ///
  /// Returns an [IncomingLink] if the URI belongs to the configured domain,
  /// or `null` otherwise.
  static IncomingLink? handleIncomingUri(Uri uri) {
    if (_domain == null) return null;
    final domainHost = Uri.tryParse(_domain!)?.host ?? '';
    if (uri.host != domainHost && !uri.host.isEmpty) {
      return IncomingLink.fromUri(uri);
    }
    return IncomingLink.fromUri(uri);
  }

  // ── Link creation ─────────────────────────────────────────────────────────

  /// Create a deep link programmatically.
  ///
  /// ```dart
  /// final link = await Deeplink.createLink(
  ///   destinationUrl: 'https://yourapp.com/product/123',
  ///   params: {'product_id': '123'},
  ///   utmCampaign: 'launch',
  /// );
  /// Share.share(link!.url);
  /// ```
  static Future<CreatedLink?> createLink({
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
    _requireConfigured();
    return _client!.createLink(
      destinationUrl: destinationUrl,
      iosUrl: iosUrl,
      androidUrl: androidUrl,
      alias: alias,
      title: title,
      description: description,
      params: params,
      utmSource: utmSource,
      utmMedium: utmMedium,
      utmCampaign: utmCampaign,
      expiresAt: expiresAt,
    );
  }

  // ── Event tracking ────────────────────────────────────────────────────────

  /// Track a custom event.
  ///
  /// ```dart
  /// await Deeplink.track('purchase', {'amount': 49.99, 'currency': 'USD'});
  /// ```
  static Future<void> track(
    String event, [
    Map<String, dynamic> properties = const {},
  ]) async {
    _requireConfigured();
    final sessionId = await _sessionId();
    await _client!.trackEvent(
      name: event,
      properties: properties,
      sessionId: sessionId,
    );
  }

  // ── Impression tracking ───────────────────────────────────────────────────

  /// Record an impression for a link displayed in-app.
  ///
  /// Opening the link URL already records an impression automatically.
  /// Call this only when you show a deep link inside a banner or share sheet
  /// without the user actually opening the link URL.
  ///
  /// ```dart
  /// await Deeplink.recordImpression('summer-sale');
  /// ```
  static Future<void> recordImpression(String alias) async {
    _requireConfigured();
    await _client!.recordImpression(alias: alias);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Reset the "already fetched" flag (useful for testing).
  static Future<void> resetInitState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyInitFetched);
  }

  static void _requireConfigured() {
    assert(_client != null, 'Deeplink.configure() must be called before using the SDK');
  }

  static Future<String> _sessionId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_keySessionId);
    if (existing != null) return existing;
    final newId = const Uuid().v4();
    await prefs.setString(_keySessionId, newId);
    return newId;
  }
}
