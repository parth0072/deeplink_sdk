import SwiftUI
import DeeplinkSDK

@main
struct SampleApp: App {

    init() {
        // ── Step 1: Configure the SDK ─────────────────────────────────────────
        // Call once on launch. Replace with your real API key and domain.
        Deeplink.configure(
            apiKey: "7f9d682990f7b0d1502906357a35cd5f886293f8cf2377d3",
            domain: "https://deeplinkbe-production-5e4b.up.railway.app"
        )

        // ── Step 2: Fetch deferred deep link on first install ─────────────────
        // This matches the install fingerprint against the click that led
        // the user to install. Call once after onboarding completes.
        Deeplink.getInitData { data in
            guard let data = data else {
                print("[Deeplink] No deferred deep link found.")
                return
            }
            print("[Deeplink] Matched install!")
            print("  → destination : \(data.destinationUrl)")
            print("  → iosUrl      : \(data.iosUrl ?? "—")")
            print("  → metadata    : \(data.metadata)")
            print("  → utmCampaign : \(data.utmCampaign ?? "—")")
            print("  → creative    : \(data.creativeName ?? "—") / \(data.creativeId ?? "—")")

            // TODO: Navigate to the deep-linked screen in your app
            // e.g. router.navigate(to: data.iosUrl ?? data.destinationUrl)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // ── Step 3: Handle universal links / custom URL schemes ──
                    Deeplink.handleIncomingURL(url) { link in
                        guard let link = link else { return }
                        print("[Deeplink] Incoming URL: \(url)")
                        print("  → pathComponents : \(link.pathComponents)")
                        print("  → params         : \(link.params)")
                    }
                }
        }
    }
}
