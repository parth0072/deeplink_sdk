import Foundation

final class APIClient {
    private let config: DeeplinkConfig
    private let session: URLSession

    init(config: DeeplinkConfig) {
        self.config = config
        self.session = URLSession(configuration: .default)
    }

    /// POST /sdk/init — fetch deferred deep link data on first launch.
    func fetchInitData(completion: @escaping (DeeplinkData?) -> Void) {
        var url = config.apiBaseURL
        url.appendPathComponent("sdk/init")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "api_key": config.apiKey,
            "user_agent": userAgent(),
        ]
        request.httpBody = try? JSONEncoder().encode(body)

        let task = session.dataTask(with: request) { data, _, error in
            guard error == nil, let data = data else {
                completion(nil)
                return
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            guard
                let response = try? decoder.decode(SDKInitResponse.self, from: data),
                response.matched,
                let linkData = response.data
            else {
                completion(nil)
                return
            }
            completion(linkData.toDeeplinkData())
        }
        task.resume()
    }

    // MARK: - Helpers

    private func userAgent() -> String {
        let info = Bundle.main.infoDictionary
        let appName = info?["CFBundleName"] as? String ?? "App"
        let appVersion = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let os = "iOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
        return "\(appName)/\(appVersion) \(os)"
    }
}
