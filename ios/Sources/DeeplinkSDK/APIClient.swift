import Foundation
import UIKit

internal final class APIClient {
    private let config: DeeplinkConfig
    private let session: URLSession

    init(config: DeeplinkConfig) {
        self.config = config
        self.session = URLSession(configuration: .default)
    }

    // MARK: - SDK Endpoints

    func fetchInitData(completion: @escaping (DeeplinkData?) -> Void) {
        var body: [String: Any] = [
            "api_key": config.apiKey,
            "user_agent": userAgent(),
        ]
        // Device signals for probabilistic fingerprint matching
        body["device_model"] = deviceModel()
        body["os_version"]   = UIDevice.current.systemVersion
        body["screen_res"]   = screenRes()
        body["timezone"]     = TimeZone.current.identifier
        body["language"]     = Locale.current.languageCode ?? "en"

        post("/sdk/init", body: body) { (response: SDKInitResponse?) in
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

    /// Record an impression for a link shown in-app.
    /// Opening the link URL already auto-records an impression; call this only
    /// when you display a link inside a banner or share sheet without opening it.
    func recordImpression(alias: String, completion: ((Bool) -> Void)? = nil) {
        post("/api/impressions", body: [
            "api_key": config.apiKey,
            "link_alias": alias,
            "platform": "ios",
        ]) { (_: EmptyResponse?) in completion?(true) }
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

    /// Returns the hardware model identifier, e.g. "iPhone15,2".
    private func deviceModel() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }

    /// Returns screen resolution as "widthxheightxscale", matching what the web
    /// browser JS reports via `screen.width + 'x' + screen.height + 'x' + devicePixelRatio`.
    private func screenRes() -> String {
        var result = ""
        let capture = {
            let s = UIScreen.main
            let w = Int(s.bounds.width)
            let h = Int(s.bounds.height)
            let scale = Int(s.scale)
            result = "\(w)x\(h)x\(scale)"
        }
        if Thread.isMainThread { capture() } else { DispatchQueue.main.sync { capture() } }
        return result
    }
}

private struct EmptyResponse: Decodable {}
