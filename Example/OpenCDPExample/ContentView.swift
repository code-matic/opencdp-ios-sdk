// ContentView.swift
// OpenCDP iOS SDK — Example App
//
// Demonstrates the complete SDK flow:
//   1. Identify a user
//   2. Track a custom event
//   3. Track a screen view
//   4. Register a device token (simulated)
//   5. Clear identity (logout)

import SwiftUI
import OpenCDP

struct ContentView: View {

    @State private var log: [String] = []
    private let userID = "user_12345"

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {

                // ─── Action Buttons ──────────────────────────────────────────
                Group {
                    ActionButton(title: "1. Identify User", color: .blue) {
                        identifyUser()
                    }
                    ActionButton(title: "2. Track Event", color: .green) {
                        trackEvent()
                    }
                    ActionButton(title: "3. Track Screen View", color: .orange) {
                        trackScreen()
                    }
                    ActionButton(title: "4. Register Device Token", color: .purple) {
                        registerDevice()
                    }
                    ActionButton(title: "5. Clear Identity (Logout)", color: .red) {
                        clearIdentity()
                    }
                }
                .padding(.horizontal)

                Divider().padding(.vertical, 4)

                // ─── Log Output ──────────────────────────────────────────────
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(log, id: \.self) { entry in
                            Text(entry)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal)
                }
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            .padding(.top)
            .navigationTitle("OpenCDP Example")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear Log") { log.removeAll() }
                }
            }
        }
        .onAppear {
            // Track this screen view on appear
            OpenCDP.shared.trackScreenView(title: "HomeScreen")
            appendLog("📱 Screen view: HomeScreen")
        }
    }

    // ─── SDK Actions ─────────────────────────────────────────────────────────

    private func identifyUser() {
        OpenCDP.shared.identify(
            identifier: userID,
            properties: [
                "name": "John Doe",
                "email": "john.doe@example.com",
                "plan": "premium"
            ]
        )
        appendLog("✅ Identified user: \(userID)")
    }

    private func trackEvent() {
        OpenCDP.shared.track(
            eventName: "item_purchased",
            properties: [
                "item_id": "prod_999",
                "price": 49.99,
                "currency": "USD"
            ]
        )
        appendLog("✅ Tracked event: item_purchased")
    }

    private func trackScreen() {
        OpenCDP.shared.trackScreenView(
            title: "ProductDetails",
            properties: ["sku": "X-001"]
        )
        appendLog("✅ Screen view tracked: ProductDetails")
    }

    private func registerDevice() {
        // In a real app this token comes from AppDelegate:
        // func application(_:didRegisterForRemoteNotificationsWithDeviceToken:)
        let simulatedToken = "simulated-apns-token-abc123"
        OpenCDP.shared.registerDeviceToken(simulatedToken)
        appendLog("✅ Device token registered")
    }

    private func clearIdentity() {
        OpenCDP.shared.clearIdentity()
        appendLog("🔒 Identity cleared (logged out)")
    }

    private func appendLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(
            from: Date(), dateStyle: .none, timeStyle: .medium
        )
        log.append("[\(timestamp)] \(message)")
    }
}

// ─── Reusable Button ─────────────────────────────────────────────────────────

struct ActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color)
                .foregroundColor(.white)
                .cornerRadius(8)
                .font(.system(size: 15, weight: .semibold))
        }
    }
}

#Preview {
    ContentView()
}
