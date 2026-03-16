import Foundation
import UIKit

/// Main entry point for the Deeplink SDK.
///
/// ## Quick Start
///
/// **1. Configure (AppDelegate or @main):**
/// ```swift
/// Deeplink.configure(apiKey: "your-api-key", domain: "dl.yourapp.com")
/// ```
///
/// **2. Handle universal links (SceneDelegate):**
/// ```swift
/// func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
///     guard let url = userActivity.webpageURL else { return }
///     Deeplink.handleIncomingURL(url) { link in
///         // Navigate using link.pathComponents or link.params
///     }
/// }
/// ```
///
/// **3. Deferred deep link on first launch:**
/// ```swift
/// Deeplink.getInitData { data in
///     guard let data else { return }
///     // Navigate to data.iosUrl or parse data.destinationUrl
/// }
/// ```
///
/// ## Info.plist auto-configuration
/// Add `DeeplinkAPIKey` and `DeeplinkDomain` to your Info.plist to configure
/// without writing any code — useful for CI/CD and multi-environment builds.
///
/// ## Debug mode
/// ```swift
/// Deeplink.setDebug(true)  // Call before configure()
/// Deeplink.configure(...)
/// ```
public final class Deeplink {
    // MARK: - Singleton

    private static var shared: Deeplink?

    private let config: DeeplinkConfig
    private let apiClient: APIClient
    private let linkHandler: LinkHandler

    private static let initDataKey    = "dl_sdk_init_data_fetched"
    private static let firstLaunchKey = "dl_sdk_first_launch_done"
    private static let sessionIdKey   = "dl_sdk_session_id"

    /// In-memory cache: alias → DeeplinkData. Populated by getInitData/onFirstLaunch.
    /// getLinkData checks here first — avoids a redundant network call.
    private static var linkDataCache: [String: DeeplinkData] = [:]

    private init(config: DeeplinkConfig) {
        self.config = config
        self.apiClient = APIClient(config: config)
        self.linkHandler = LinkHandler(config: config)
    }

    // MARK: - Public API

    /// Enable verbose logging. Call this **before** `configure()`.
    ///
    /// Logs are written via `os.log` (visible in Console.app) and also printed
    /// to Xcode's debug output for convenience.
    ///
    /// ```swift
    /// Deeplink.setDebug(true)
    /// Deeplink.configure(apiKey: "...", domain: "...")
    /// ```
    public static func setDebug(_ enabled: Bool) {
        DeeplinkLogger.isEnabled = enabled
        DeeplinkLogger.log("Debug mode \(enabled ? "enabled" : "disabled")")
    }

    /// Configure the SDK. Call this once on app launch before any other SDK methods.
    ///
    /// Alternatively, set `DeeplinkAPIKey` and `DeeplinkDomain` in Info.plist and
    /// call `Deeplink.configureFromInfoPlist()` instead.
    public static func configure(apiKey: String, domain: String) {
        guard shared == nil else {
            DeeplinkLogger.log("configure — already configured, skipping duplicate call")
            return
        }
        let config = DeeplinkConfig(apiKey: apiKey, domain: domain)
        shared = Deeplink(config: config)
        DeeplinkLogger.log("Configured — apiKey=\(apiKey.prefix(8))*** domain=\(domain)")
    }

    /// Configure the SDK using `DeeplinkAPIKey` and `DeeplinkDomain` from Info.plist.
    ///
    /// Returns `false` if the Info.plist keys are missing. Useful for multi-environment
    /// builds where each target's Info.plist has different keys.
    @discardableResult
    public static func configureFromInfoPlist() -> Bool {
        guard let config = DeeplinkConfig.fromInfoPlist() else {
            DeeplinkLogger.error("configureFromInfoPlist — DeeplinkAPIKey or DeeplinkDomain missing from Info.plist")
            return false
        }
        shared = Deeplink(config: config)
        DeeplinkLogger.log("Configured from Info.plist — domain=\(config.domain)")
        return true
    }

    /// Enable clipboard-based deferred deep link attribution (opt-in).
    ///
    /// When enabled, `getInitData()` reads `UIPasteboard.general.string` on the
    /// first call to look for a click ID written by the redirect page. If found,
    /// the match is 100% deterministic (no probabilistic scoring needed).
    ///
    /// **Note:** Reading `UIPasteboard.general` shows the iOS 16+ "pasted from" toast.
    /// Only call this if you are comfortable showing that notification.
    ///
    /// ```swift
    /// Deeplink.checkPasteboardOnInstall()
    /// Deeplink.getInitData { data in ... }
    /// ```
    public static func checkPasteboardOnInstall() {
        shared?.apiClient.pasteboardCheckEnabled = true
        DeeplinkLogger.log("Clipboard attribution enabled")
    }

    /// Handle an incoming URL (universal link or custom URL scheme).
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
    ///
    /// Call this **once** on first launch (e.g. after onboarding completes).
    /// Subsequent calls are no-ops unless `force: true`.
    ///
    /// - Parameter force: If `true`, re-fetches even if already matched once.
    /// - Parameter completion: Called on the main thread with `DeeplinkData` or `nil`.
    public static func getInitData(force: Bool = false, completion: @escaping (DeeplinkData?) -> Void) {
        guard let sdk = shared else {
            assertionFailure("Deeplink.configure() must be called first")
            completion(nil)
            return
        }

        let alreadyFetched = UserDefaults.standard.bool(forKey: initDataKey)
        guard !alreadyFetched || force else {
            DeeplinkLogger.log("getInitData — already fetched, skipping (use force: true to re-fetch)")
            completion(nil)
            return
        }

        DeeplinkLogger.log("getInitData — fetching...")

        sdk.apiClient.fetchInitData { data in
            if let data {
                UserDefaults.standard.set(true, forKey: initDataKey)
                linkDataCache[data.alias] = data
                DeeplinkLogger.log("getInitData — match found: alias=\(data.alias)")
            } else {
                DeeplinkLogger.log("getInitData — no match")
            }
            DispatchQueue.main.async { completion(data) }
        }
    }

    /// Register a callback that fires **only on the very first app install**.
    ///
    /// Unlike `getInitData`, this fires even when there is no deep link to route —
    /// useful for showing onboarding, recording an install event, or awarding
    /// install bonuses.
    ///
    /// Subsequent app launches (including updates and reinstalls from the same
    /// Keychain device ID) will NOT trigger this callback.
    ///
    /// ```swift
    /// Deeplink.onFirstLaunch { data in
    ///     Analytics.track("install", properties: ["source": data?.utmSource ?? "organic"])
    ///     if let data { navigateTo(data.iosUrl) }
    /// }
    /// ```
    public static func onFirstLaunch(completion: @escaping (DeeplinkData?) -> Void) {
        let done = UserDefaults.standard.bool(forKey: firstLaunchKey)
        guard !done else {
            DeeplinkLogger.log("onFirstLaunch — already fired, skipping")
            return
        }

        UserDefaults.standard.set(true, forKey: firstLaunchKey)
        DeeplinkLogger.log("onFirstLaunch — first install detected, fetching init data")

        // Piggy-back on getInitData but always call completion, even with nil
        guard let sdk = shared else {
            assertionFailure("Deeplink.configure() must be called first")
            return
        }
        sdk.apiClient.fetchInitData { data in
            if data != nil {
                UserDefaults.standard.set(true, forKey: initDataKey)
            }
            DispatchQueue.main.async { completion(data) }
        }
    }

    /// Create a deep link programmatically.
    ///
    /// The `params` dictionary is returned by `getInitData()` when the recipient opens
    /// the app, letting you pass arbitrary data through the link.
    ///
    /// ```swift
    /// Deeplink.createLink(
    ///     destination: "https://yourapp.com/product/123",
    ///     params: ["product_id": "123", "promo": "launch10"]
    /// ) { result, error in
    ///     guard let result else { return }
    ///     share(result.url)
    /// }
    /// ```
    /// Create a deep link programmatically.
    ///
    /// ```swift
    /// Deeplink.createLink(
    ///     destination: "https://yourapp.com/product/123",
    ///     params: ["product_id": "123"],
    ///     title: "Check out this product",
    ///     description: "Limited time offer",
    ///     ogImage: "https://yourapp.com/images/product.jpg",
    ///     utmSource: "instagram",
    ///     utmCampaign: "summer_sale"
    /// ) { result, error in
    ///     guard let result else { return }
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
        ogImage: String? = nil,
        utmSource: String? = nil,
        utmMedium: String? = nil,
        utmCampaign: String? = nil,
        utmContent: String? = nil,
        utmTerm: String? = nil,
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
            ogImage: ogImage,
            utmSource: utmSource,
            utmMedium: utmMedium,
            utmCampaign: utmCampaign,
            utmContent: utmContent,
            utmTerm: utmTerm,
            expiresAt: expiresAt
        ) { result, error in
            DispatchQueue.main.async { completion(result, error) }
        }
    }

    /// Record an impression for a link displayed in-app.
    ///
    /// Opening the link URL already records an impression automatically.
    /// Call this only when you show a link inside a banner/share sheet without opening it.
    public static func recordImpression(alias: String, completion: ((Bool) -> Void)? = nil) {
        guard let sdk = shared else {
            assertionFailure("Deeplink.configure() must be called first")
            return
        }
        sdk.apiClient.recordImpression(alias: alias, completion: completion)
    }

    /// Fetch server-stored params/metadata for a link by alias.
    ///
    /// Call this after `handleIncomingURL` returns an `IncomingLink` to retrieve the
    /// `params` dictionary that was set when the link was created — these are NOT
    /// embedded in the URL and require a server lookup.
    ///
    /// ```swift
    /// Deeplink.handleIncomingURL(url) { link in
    ///     guard let link else { return }
    ///     let alias = link.pathComponents.first ?? ""
    ///     Deeplink.getLinkData(alias: alias) { data in
    ///         let productId = data?.metadata["product_id"]
    ///     }
    /// }
    /// ```
    public static func getLinkData(alias: String, completion: @escaping (DeeplinkData?) -> Void) {
        guard let sdk = shared else {
            assertionFailure("Deeplink.configure() must be called first")
            completion(nil)
            return
        }
        // Return cached result if getInitData already fetched this alias — no extra network call
        if let cached = linkDataCache[alias] {
            DeeplinkLogger.log("getLinkData — cache hit for alias=\(alias)")
            DispatchQueue.main.async { completion(cached) }
            return
        }
        sdk.apiClient.fetchLinkData(alias: alias) { data in
            if let data { linkDataCache[alias] = data }
            DispatchQueue.main.async { completion(data) }
        }
    }

    /// Track a custom event.
    ///
    /// Property values must be JSON-serialisable types (String, Int, Double, Bool).
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

    /// Reset the "already fetched" and "first launch" flags (useful for testing).
    public static func resetInitState() {
        UserDefaults.standard.removeObject(forKey: initDataKey)
        UserDefaults.standard.removeObject(forKey: firstLaunchKey)
        DeeplinkLogger.log("resetInitState — flags cleared")
    }

    // MARK: - Session

    private static func currentSessionId() -> String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: sessionIdKey) { return existing }
        let newId = UUID().uuidString
        defaults.set(newId, forKey: sessionIdKey)
        return newId
    }
}
