import SwiftUI
import DeeplinkSDK

struct ContentView: View {

    @State private var log: [String] = ["SDK configured. Ready to test."]
    @State private var createdLinkURL: String = ""
    @State private var isFetching = false
    @State private var isCreating = false

    var body: some View {
        NavigationView {
            List {

                // ── Deferred Deep Link ────────────────────────────────────────
                Section("Deferred Deep Link") {
                    Button {
                        append("Fetching init data…")
                        isFetching = true
                        Deeplink.getInitData(force: true) { data in
                            isFetching = false
                            if let data = data {
                                append("✅ Matched!")
                                append("   dest: \(data.destinationUrl)")
                                append("   iosUrl: \(data.iosUrl ?? "—")")
                                append("   utm: \(data.utmCampaign ?? "—")")
                                append("   metadata: \(data.metadata)")
                            } else {
                                append("⚠️ No match (no click fingerprint found)")
                            }
                        }
                    } label: {
                        Label(
                            isFetching ? "Fetching…" : "Get Init Data (force)",
                            systemImage: "antenna.radiowaves.left.and.right"
                        )
                    }
                    .disabled(isFetching)

                    Button {
                        Deeplink.resetInitState()
                        append("🔄 Init state reset — next getInitData() will re-fetch")
                    } label: {
                        Label("Reset Init State", systemImage: "arrow.counterclockwise")
                    }
                }

                // ── Create Link ───────────────────────────────────────────────
                Section("Create Link") {
                    Button {
                        append("Creating link…")
                        isCreating = true
                        Deeplink.createLink(
                            destination: "https://yourapp.com/product/123",
                            params: ["product_id": "123", "source": "sample-app"],
                            iosUrl: "myapp://product/123",
                            alias: nil,
                            title: "Sample Product",
                            utmSource: "sample",
                            utmMedium: "ios",
                            utmCampaign: "sdk-test"
                        ) { result, error in
                            isCreating = false
                            if let result = result {
                                createdLinkURL = result.url
                                append("✅ Link created: \(result.url)")
                                append("   alias: \(result.alias)")
                                append("   linkId: \(result.linkId)")
                            } else {
                                append("❌ Error: \(error?.localizedDescription ?? "unknown")")
                                append("   (Is the backend running and API key correct?)")
                            }
                        }
                    } label: {
                        Label(
                            isCreating ? "Creating…" : "Create Deep Link",
                            systemImage: "link.badge.plus"
                        )
                    }
                    .disabled(isCreating)

                    if !createdLinkURL.isEmpty {
                        HStack {
                            Text(createdLinkURL)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = createdLinkURL
                                append("📋 Copied to clipboard")
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                // ── Event Tracking ────────────────────────────────────────────
                Section("Event Tracking") {
                    Button {
                        Deeplink.track("button_tapped", properties: [
                            "screen": "home",
                            "button": "track_test",
                        ])
                        append("📊 Tracked: button_tapped")
                    } label: {
                        Label("Track button_tapped", systemImage: "chart.bar")
                    }

                    Button {
                        Deeplink.track("purchase", properties: [
                            "amount": 49.99,
                            "currency": "USD",
                            "product_id": "123",
                        ])
                        append("📊 Tracked: purchase { amount: 49.99, currency: USD }")
                    } label: {
                        Label("Track purchase event", systemImage: "cart")
                    }

                    Button {
                        Deeplink.track("signup")
                        append("📊 Tracked: signup")
                    } label: {
                        Label("Track signup event", systemImage: "person.badge.plus")
                    }
                }

                // ── Log ───────────────────────────────────────────────────────
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(log.reversed(), id: \.self) { line in
                            Text(line)
                                .font(.caption.monospaced())
                                .foregroundStyle(
                                    line.hasPrefix("❌") ? Color.red :
                                    line.hasPrefix("✅") ? Color.green :
                                    line.hasPrefix("📊") ? Color.blue :
                                    Color.primary
                                )
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    HStack {
                        Text("Log")
                        Spacer()
                        Button("Clear") { log = [] }
                            .font(.caption)
                    }
                }

            }
            .navigationTitle("Deeplink SDK Sample")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func append(_ message: String) {
        DispatchQueue.main.async {
            log.append(message)
        }
    }
}

#Preview {
    ContentView()
}
