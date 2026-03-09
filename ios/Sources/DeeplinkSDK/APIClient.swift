import Foundation

internal final class APIClient {
    private let config: DeeplinkConfig
    private let session: URLSession

    init(config: DeeplinkConfig) {
        self.config = config
        self.session = URLSession(configuration: .default)
    }

    // MARK: - SDK Endpoints

    func fetchInitData(completion: @escaping (DeeplinkData?) -> Void) {
        post("/sdk/init", body: [
            "api_key": config.apiKey,
            "user_agent": userAgent(),
        ]) { (response: SDKInitResponse?) in
            guard let response, response.matched, let data = response.data else {
                completion(nil); return
            }
            completion(data.toDeeplinkData())
        }
    }

    func createLink(
        destination: String,
        params: [String: String],
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
        var body: [String: Any] = [
            "api_key": config.apiKey,
            "destination_url": destination,
        ]
        if !params.isEmpty     { body["params"]       = params }
        if let v = iosUrl      { body["ios_url"]      = v }
        if let v = androidUrl  { body["android_url"]  = v }
        if let v = alias       { body["alias"]        = v }
        if let v = title       { body["title"]        = v }
        if let v = description { body["description"]  = v }
        if let v = utmSource   { body["utm_source"]   = v }
        if let v = utmMedium   { body["utm_medium"]   = v }
        if let v = utmCampaign { body["utm_campaign"] = v }
        if let v = expiresAt   { body["expires_at"]   = v }

        post("/sdk/link", body: body) { (parsed: SDKCreateLinkResponse?) in
            guard let parsed else {
                completion(nil, URLError(.cannotParseResponse)); return
            }
            completion(CreatedLink(url: parsed.url, alias: parsed.alias, linkId: parsed.linkId), nil)
        }
    }

    func trackEvent(name: String, properties: [String: Any], sessionId: String, completion: ((Bool) -> Void)? = nil) {
        var body: [String: Any] = [
            "api_key": config.apiKey,
            "name": name,
            "session_id": sessionId,
        ]
        if !properties.isEmpty { body["properties"] = properties }
        post("/api/events", body: body) { (_: EmptyResponse?) in completion?(true) }
    }

    // MARK: - Common HTTP helper

    private func post<T: Decodable>(_ path: String, body: [String: Any], completion: @escaping (T?) -> Void) {
        guard
            let url = URL(string: config.apiBaseURL.absoluteString + path),
            let bodyData = try? JSONSerialization.data(withJSONObject: body)
        else { completion(nil); return }

        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = bodyData

        session.dataTask(with: req) { data, response, _ in
            guard
                let data,
                let http = response as? HTTPURLResponse,
                (200...299).contains(http.statusCode)
            else { completion(nil); return }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            completion(try? decoder.decode(T.self, from: data))
        }.resume()
    }

    // MARK: - Helpers

    private func userAgent() -> String {
        let info = Bundle.main.infoDictionary
        let appName    = info?["CFBundleName"] as? String ?? "App"
        let appVersion = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let os = "iOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
        return "\(appName)/\(appVersion) \(os)"
    }
}

private struct EmptyResponse: Decodable {}
