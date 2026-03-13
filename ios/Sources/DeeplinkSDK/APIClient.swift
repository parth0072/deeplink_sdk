import Foundation
import UIKit
// Note: WebKit removed — hidden WKWebView canvas collection is unreliable on iOS 17+

internal final class APIClient {
    private let config: DeeplinkConfig
    private let session: URLSession

    /// Set to true by Deeplink.checkPasteboardOnInstall() — reads UIPasteboard on /sdk/init.
    var pasteboardCheckEnabled: Bool = false

    init(config: DeeplinkConfig) {
        self.config = config
        self.session = URLSession(configuration: .default)
    }

    // MARK: - SDK Endpoints

    func fetchInitData(completion: @escaping (DeeplinkData?) -> Void) {
        // Collect all UIKit signals on main thread first to avoid deadlocks.
        // UIScreen.main, UIDevice, UIPasteboard all require main thread access.
        let collectAndFire = {
            var body: [String: Any] = [
                "api_key":    self.config.apiKey,
                "user_agent": self.userAgent(),
            ]

            // Keychain device ID — survives reinstall, deterministic on returning users
            body["device_id"] = KeychainHelper.getOrCreateDeviceId()

            // IDFV — Apple's stable per-vendor identifier, no ATT needed.
            if let idfv = UIDevice.current.identifierForVendor?.uuidString {
                body["idfv"] = idfv
            }

            // iOS Clipboard attribution (opt-in via checkPasteboardOnInstall).
            // The redirect page writes "deeplink-click:{fingerprintId}" to UIPasteboard
            // when the user taps "Open in Browser" → App Store.
            // Note: reading UIPasteboard.general triggers the iOS 16+ "pasted from" toast.
            if self.pasteboardCheckEnabled {
                if let pasteStr = UIPasteboard.general.string,
                   pasteStr.hasPrefix("deeplink-click:") {
                    let clickId = String(pasteStr.dropFirst("deeplink-click:".count))
                    if !clickId.isEmpty {
                        body["pasteboard_click_id"] = clickId
                        UIPasteboard.general.string = nil
                    }
                }
            }

            // Native device signals for probabilistic scoring
            body["device_model"] = self.deviceModel()
            body["os_version"]   = UIDevice.current.systemVersion
            body["screen_res"]   = self.screenRes()
            body["timezone"]     = TimeZone.current.identifier
            body["language"]     = Locale.current.languageCode ?? "en"

            // Fire network call on background thread — never block the main thread
            DispatchQueue.global(qos: .userInitiated).async {
                self.post("/sdk/init", body: body) { (response: SDKInitResponse?) in
                    guard let response, response.matched, let data = response.data else {
                        completion(nil); return
                    }
                    completion(data.toDeeplinkData())
                }
            }
        }

        if Thread.isMainThread {
            collectAndFire()
        } else {
            DispatchQueue.main.async { collectAndFire() }
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
    /// Uses sysctlbyname — safe to call on any thread.
    private func deviceModel() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }

    /// Returns screen resolution as "widthxheightxscale".
    /// Must be called on the main thread — enforced by fetchInitData().
    private func screenRes() -> String {
        let s = UIScreen.main
        let w = Int(s.bounds.width)
        let h = Int(s.bounds.height)
        let scale = Int(s.scale)
        return "\(w)x\(h)x\(scale)"
    }
}

private struct EmptyResponse: Decodable {}
