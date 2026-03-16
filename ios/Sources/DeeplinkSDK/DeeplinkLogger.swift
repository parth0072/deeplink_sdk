import Foundation

/// Internal debug logger. Enable via `Deeplink.setDebug(true)`.
internal enum DeeplinkLogger {
    static var isEnabled = false

    static func log(_ message: String) {
        guard isEnabled else { return }
        print("[Deeplink] \(message)")
    }

    static func error(_ message: String, _ err: Error? = nil) {
        guard isEnabled else { return }
        let suffix = err.map { " — \($0)" } ?? ""
        print("[Deeplink] ❌ \(message)\(suffix)")
    }
}
