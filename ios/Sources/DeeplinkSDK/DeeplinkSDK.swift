import Foundation

/// Main entry point for the Deeplink SDK.
///
/// **Setup (AppDelegate / @main):**
/// ```swift
/// Deeplink.configure(apiKey: "your-api-key", domain: "dl.yourapp.com")
/// ```
///
/// **Handle universal links (SceneDelegate):**
/// ```swift
/// func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
///     guard let url = userActivity.webpageURL else { return }
///     Deeplink.handleIncomingURL(url) { link in
///         // Navigate using link.pathComponents or link.params
///     }
/// }
/// ```
///
/// **Deferred deep link (first launch):**
/// ```swift
/// Deeplink.getInitData { data in
///     guard let data = data else { return }
///     // Navigate to data.iosUrl or parse data.destinationUrl
/// }
/// ```
public final class Deeplink {
    // MARK: - Singleton

    private static var shared: Deeplink?

    private let config: DeeplinkConfig
    private let apiClient: APIClient
    private let linkHandler: LinkHandler

    private static let initDataKey = "dl_sdk_init_data_fetched"
    private static let sessionIdKey = "dl_sdk_session_id"

    private init(config: DeeplinkConfig) {
        self.config = config
        self.apiClient = APIClient(config: config)
        self.linkHandler = LinkHandler(config: config)
    }

    // MARK: - Public API

    /// Configure the SDK. Call this once on app launch before any other SDK methods.
    public static func configure(apiKey: String, domain: String) {
        shared = Deeplink(config: DeeplinkConfig(apiKey: apiKey, domain: domain))
    }

    /// Handle an incoming URL (universal link or custom URL scheme).
    /// - Returns: Parsed ``IncomingLink`` if the URL belongs to this SDK's domain.
    @discardableResult
    public static func handleIncomingURL(_ url: URL, completion: ((IncomingLink?) -> Void)? = nil) -> IncomingLink? {
        guard let sdk = shared else {
            assertionFailure("Deeplink.configure() must be called before handling URLs")
            return nil
        }
        let link = sdk.linkHandler.handle(url: url)
        completion?(link)
        return link
    }

    /// Fetch deferred deep link data from the server.
    /// Call this once on first launch (e.g. after onboarding completes).
    /// Subsequent calls are no-ops unless `force` is true.
    public static func getInitData(force: Bool = false, completion: @escaping (DeeplinkData?) -> Void) {
        guard let sdk = shared else {
            assertionFailure("Deeplink.configure() must be called first")
            completion(nil)
            return
        }

        let alreadyFetched = UserDefaults.standard.bool(forKey: initDataKey)
        guard !alreadyFetched || force else {
            completion(nil)
            return
        }

        sdk.apiClient.fetchInitData { data in
            if data != nil {
                UserDefaults.standard.set(true, forKey: initDataKey)
            }
            DispatchQueue.main.async {
                completion(data)
            }
        }
    }

    /// Create a deep link programmatically.
    ///
    /// The `params` dictionary is stored as link metadata and returned by `getInitData()`
    /// when the recipient opens the app, letting you pass arbitrary data through the link.
    ///
    /// ```swift
    /// Deeplink.createLink(
    ///     destination: "https://yourapp.com/product/123",
    ///     params: ["product_id": "123", "promo": "launch10"],
    ///     utmCampaign: "launch"
    /// ) { result, error in
    ///     guard let result = result else { return }
    ///     share(result.url)
    /// }
    /// ```
    public static func createLink(
        destination: String,
        params: [String: String] = [:],
        iosUrl: String? = nil,
        androidUrl: String? = nil,
        alias: String? = nil,
        title: String? = nil,
        description: String? = nil,
        utmSource: String? = nil,
        utmMedium: String? = nil,
        utmCampaign: String? = nil,
        expiresAt: String? = nil,
        completion: @escaping (CreatedLink?, Error?) -> Void
    ) {
        guard let sdk = shared else {
            assertionFailure("Deeplink.configure() must be called first")
            completion(nil, nil)
            return
        }
        sdk.apiClient.createLink(
            destination: destination,
            params: params,
            iosUrl: iosUrl,
            androidUrl: androidUrl,
            alias: alias,
            title: title,
            description: description,
            utmSource: utmSource,
            utmMedium: utmMedium,
            utmCampaign: utmCampaign,
            expiresAt: expiresAt
        ) { result, error in
            DispatchQueue.main.async {
                completion(result, error)
            }
        }
    }

    /// Track a custom event. Properties values must be JSON-serialisable types
    /// (String, Int, Double, Bool).
    ///
    /// ```swift
    /// Deeplink.track("purchase", properties: ["amount": 49.99, "currency": "USD"])
    /// ```
    public static func track(_ name: String, properties: [String: Any] = [:]) {
        guard let sdk = shared else {
            assertionFailure("Deeplink.configure() must be called first")
            return
        }
        sdk.apiClient.trackEvent(name: name, properties: properties, sessionId: currentSessionId())
    }

    /// Reset the "already fetched" flag (useful for testing).
    public static func resetInitState() {
        UserDefaults.standard.removeObject(forKey: initDataKey)
    }

    // MARK: - Session

    /// Returns the persistent session ID, creating one on first call.
    private static func currentSessionId() -> String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: sessionIdKey) {
            return existing
        }
        let newId = UUID().uuidString
        defaults.set(newId, forKey: sessionIdKey)
        return newId
    }
}
