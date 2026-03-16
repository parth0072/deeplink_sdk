import Foundation
import UIKit

internal final class APIClient {
    private let config: DeeplinkConfig
    private let session: URLSession

    /// Set to true by Deeplink.checkPasteboardOnInstall()
    var pasteboardCheckEnabled: Bool = false

    /// In-flight deduplication — queues completions so calling getInitData() and
    /// onFirstLaunch() together in AppDelegate fires only ONE network request.
    private var pendingInitCompletions: [(DeeplinkData?) -> Void] = []
    private var initFetchInFlight = false
    private let initLock = NSLock()

    init(config: DeeplinkConfig) {
        self.config = config
        self.session = URLSession(configuration: .default)
    }

    // MARK: - SDK Endpoints

    func fetchInitData(completion: @escaping (DeeplinkData?) -> Void) {
        // Collect all UIKit signals on the main thread first.
        // UIScreen.main, UIDevice, UIPasteboard must be accessed on main thread.
        // Then fire the network call on a background queue — never block main.
        let collectAndFire = {
            var body: [String: Any] = [
                "api_key":    self.config.apiKey,
                "user_agent": self.userAgent(),
            ]

            // Keychain device ID — survives reinstall, deterministic on returning users.
            let deviceId = KeychainHelper.getOrCreateDeviceId()
            body["device_id"] = deviceId
            DeeplinkLogger.log("fetchInitData — device_id: \(deviceId)")

            // IDFV — Apple's stable per-vendor identifier, no ATT required.
            if let idfv = UIDevice.current.identifierForVendor?.uuidString {
                body["idfv"] = idfv
                DeeplinkLogger.log("fetchInitData — idfv: \(idfv)")
            }

            // Clipboard attribution (opt-in via checkPasteboardOnInstall).
            // Note: reading UIPasteboard.general shows the iOS 16+ "pasted from" toast.
            if self.pasteboardCheckEnabled {
                if let pasteStr = UIPasteboard.general.string,
                   pasteStr.hasPrefix("deeplink-click:") {
                    let clickId = String(pasteStr.dropFirst("deeplink-click:".count))
                    if !clickId.isEmpty {
                        body["pasteboard_click_id"] = clickId
                        UIPasteboard.general.string = nil
                        DeeplinkLogger.log("fetchInitData — clipboard click_id found: \(clickId)")
                    }
                }
            }

            // Native device signals for probabilistic matching
            let model = self.deviceModel()
            let osVer = UIDevice.current.systemVersion
            let screen = self.screenRes()
            body["device_model"] = model
            body["os_version"]   = osVer
            body["screen_res"]   = screen
            body["timezone"]     = TimeZone.current.identifier
            body["language"]     = Locale.current.languageCode ?? "en"

            DeeplinkLogger.log("fetchInitData — signals: model=\(model) os=\(osVer) screen=\(screen)")

            // Deduplicate: if a fetch is already in flight, queue and return
            self.initLock.lock()
            self.pendingInitCompletions.append(completion)
            let shouldFire = !self.initFetchInFlight
            if shouldFire { self.initFetchInFlight = true }
            self.initLock.unlock()

            guard shouldFire else {
                DeeplinkLogger.log("fetchInitData — request already in flight, queued")
                return
            }

            // Network call on background thread
            DispatchQueue.global(qos: .userInitiated).async {
                self.post("/sdk/init", body: body) { (response: SDKInitResponse?) in
                    if let response {
                        DeeplinkLogger.log("fetchInitData — matched=\(response.matched) alias=\(response.data?.alias ?? "none")")
                    }
                    let data = (response?.matched == true) ? response?.data?.toDeeplinkData() : nil

                    // Drain all queued completions with the same result
                    self.initLock.lock()
                    let completions = self.pendingInitCompletions
                    self.pendingInitCompletions = []
                    self.initFetchInFlight = false
                    self.initLock.unlock()

                    completions.forEach { $0(data) }
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
        ogImage: String? = nil,
        utmSource: String? = nil,
        utmMedium: String? = nil,
        utmCampaign: String? = nil,
        utmContent: String? = nil,
        utmTerm: String? = nil,
        expiresAt: String? = nil,
        completion: @escaping (CreatedLink?, Error?) -> Void
    ) {
        var body: [String: Any] = [
            "api_key": config.apiKey,
            "destination_url": destination,
        ]
        if !params.isEmpty     { body["params"]        = params }
        if let v = iosUrl      { body["ios_url"]       = v }
        if let v = androidUrl  { body["android_url"]   = v }
        if let v = alias       { body["alias"]         = v }
        if let v = title       { body["title"]         = v }
        if let v = description { body["description"]   = v }
        if let v = ogImage     { body["og_image"]      = v }
        if let v = utmSource   { body["utm_source"]    = v }
        if let v = utmMedium   { body["utm_medium"]    = v }
        if let v = utmCampaign { body["utm_campaign"]  = v }
        if let v = utmContent  { body["utm_content"]   = v }
        if let v = utmTerm     { body["utm_term"]      = v }
        if let v = expiresAt   { body["expires_at"]    = v }

        DeeplinkLogger.log("createLink — dest=\(destination)")

        post("/sdk/link", body: body) { (parsed: SDKCreateLinkResponse?) in
            guard let parsed else {
                completion(nil, URLError(.cannotParseResponse)); return
            }
            DeeplinkLogger.log("createLink — url=\(parsed.url)")
            completion(CreatedLink(url: parsed.url, alias: parsed.alias, linkId: parsed.linkId), nil)
        }
    }

    func fetchLinkData(alias: String, completion: @escaping (DeeplinkData?) -> Void) {
        guard let url = URL(string: config.apiBaseURL.absoluteString + "/sdk/resolve/\(alias)?api_key=\(config.apiKey)")
        else { completion(nil); return }

        DeeplinkLogger.log("fetchLinkData — alias=\(alias)")

        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "GET"

        session.dataTask(with: req) { data, response, error in
            if let error { DeeplinkLogger.error("fetchLinkData error: \(error)"); completion(nil); return }
            guard let data,
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode)
            else { completion(nil); return }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if let resp = try? decoder.decode(SDKInitResponse.self, from: data), resp.matched {
                DeeplinkLogger.log("fetchLinkData — metadata=\(resp.data?.metadata ?? [:])")
                completion(resp.data?.toDeeplinkData())
            } else {
                completion(nil)
            }
        }.resume()
    }

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
        DeeplinkLogger.log("track event '\(name)' properties=\(properties)")
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

        session.dataTask(with: req) { data, response, error in
            if let error { DeeplinkLogger.error("POST \(path) error: \(error)") }
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

    /// Thread-safe hardware model via sysctlbyname, e.g. "iPhone15,2".
    private func deviceModel() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }

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
