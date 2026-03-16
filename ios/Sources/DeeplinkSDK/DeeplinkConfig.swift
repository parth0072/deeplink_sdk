import Foundation

internal struct DeeplinkConfig {
    let apiKey: String
    let domain: String

    var apiBaseURL: URL {
        let base = domain.hasPrefix("http://") || domain.hasPrefix("https://")
            ? domain
            : "https://\(domain)"
        return URL(string: base)!
    }

    /// Read configuration from Info.plist.
    /// Add `DeeplinkAPIKey` and `DeeplinkDomain` keys to your app's Info.plist
    /// to configure the SDK without any code changes.
    static func fromInfoPlist() -> DeeplinkConfig? {
        guard
            let apiKey = Bundle.main.object(forInfoDictionaryKey: "DeeplinkAPIKey") as? String,
            let domain = Bundle.main.object(forInfoDictionaryKey: "DeeplinkDomain") as? String,
            !apiKey.isEmpty, !domain.isEmpty
        else { return nil }
        return DeeplinkConfig(apiKey: apiKey, domain: domain)
    }
}
