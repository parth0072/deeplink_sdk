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
}
