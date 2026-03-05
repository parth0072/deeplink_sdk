import Foundation

/// Data returned by the SDK when a deep link is resolved.
public struct DeeplinkData {
    public let linkId: String
    public let alias: String
    public let iosUrl: String?
    public let androidUrl: String?
    public let destinationUrl: String
    public let utmSource: String?
    public let utmMedium: String?
    public let utmCampaign: String?
    public let utmContent: String?
    public let utmTerm: String?
    /// Custom key-value metadata set on the link in the dashboard.
    public let metadata: [String: String]
    /// Creative name for attribution reporting.
    public let creativeName: String?
    /// Creative ID for attribution reporting.
    public let creativeId: String?
}

// MARK: - Internal Codable representation

struct SDKInitResponse: Decodable {
    let matched: Bool
    let data: SDKInitData?
}

struct SDKInitData: Decodable {
    let linkId: String
    let alias: String
    let iosUrl: String?
    let androidUrl: String?
    let destinationUrl: String
    let utmSource: String?
    let utmMedium: String?
    let utmCampaign: String?
    let utmContent: String?
    let utmTerm: String?
    let metadata: [String: String]?
    let creativeName: String?
    let creativeId: String?

    func toDeeplinkData() -> DeeplinkData {
        DeeplinkData(
            linkId: linkId,
            alias: alias,
            iosUrl: iosUrl,
            androidUrl: androidUrl,
            destinationUrl: destinationUrl,
            utmSource: utmSource,
            utmMedium: utmMedium,
            utmCampaign: utmCampaign,
            utmContent: utmContent,
            utmTerm: utmTerm,
            metadata: metadata ?? [:],
            creativeName: creativeName,
            creativeId: creativeId
        )
    }
}
