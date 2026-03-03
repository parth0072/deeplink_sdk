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

    /// Returns true if this URL belongs to our deep link domain.
    public func canHandle(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return host == config.domain || url.scheme == urlScheme(from: config.domain)
    }

    /// Parse an incoming universal link or custom URL scheme link.
    public func handle(url: URL) -> IncomingLink? {
        guard canHandle(url: url) else { return nil }
        return IncomingLink(url: url)
    }

    private func urlScheme(from domain: String) -> String {
        domain.components(separatedBy: ".").first ?? domain
    }
}
