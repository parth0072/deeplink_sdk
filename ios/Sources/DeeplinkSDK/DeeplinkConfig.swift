import Foundation

internal struct DeeplinkConfig {
    let apiKey: String
    let domain: String

    var apiBaseURL: URL {
        URL(string: "https://\(domain)")!
    }
}
