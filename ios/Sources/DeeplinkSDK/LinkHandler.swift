import Foundation

/// Parses and exposes an incoming deep link URL.
public struct IncomingLink {
    /// The full URL that was opened.
    public let url: URL

    /// Path components (e.g. ["product", "123"] for /product/123)
    public let pathComponents: [String]

    /// Query parameters as a dictionary.
    public let params: [String: String]

    init?(url: URL) {
        self.url = url
        self.pathComponents = url.pathComponents.filter { $0 != "/" }

        var items: [String: String] = [:]
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                items[item.name] = item.value ?? ""
            }
        }
        self.params = items
    }
}

public final class LinkHandler {
    private let config: DeeplinkConfig

    init(config: DeeplinkConfig) {
        self.config = config
    }

    /// Returns true if this URL should be handled by the Deeplink SDK.
    ///
    /// Handles:
    /// - Universal links matching your configured domain
    /// - Custom URL scheme links (e.g. `myapp://`)
    public func canHandle(url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        // Custom URL scheme (not http/https) — always a deep link
        if scheme != "http" && scheme != "https" {
            DeeplinkLogger.log("Handling custom scheme URL: \(url)")
            return true
        }
        // Universal link — host must match our configured domain
        let isUniversal = url.host == config.apiBaseURL.host
        if isUniversal { DeeplinkLogger.log("Handling universal link: \(url)") }
        return isUniversal
    }

    /// Parse an incoming universal link or custom URL scheme link.
    public func handle(url: URL) -> IncomingLink? {
        guard canHandle(url: url) else { return nil }
        let link = IncomingLink(url: url)
        DeeplinkLogger.log("Parsed incoming link — path: \(link?.pathComponents ?? []), params: \(link?.params ?? [:])")
        return link
    }
}
