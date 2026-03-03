import Foundation

/// Configuration for the Deeplink SDK.
public struct DeeplinkConfig {
    /// Your app API key from the Deeplink admin panel.
    public let apiKey: String

    /// The base domain of your Deeplink server (e.g. "dl.yourapp.com").
    public let domain: String

    /// Full API base URL constructed from domain.
    var apiBaseURL: URL {
        URL(string: "https://\(domain)")!
    }

    public init(apiKey: String, domain: String) {
        self.apiKey = apiKey
        self.domain = domain
    }
}
