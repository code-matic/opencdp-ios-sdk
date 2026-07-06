// InAppDemoView.swift — demonstrates four in-app render types

import SwiftUI
import OpenCDP

private let screens = ["home", "cart", "profile", "inbox"]

struct InAppDemoView: View {
    @State private var log: [String] = []
    @State private var currentScreen = "home"
    @State private var modalMessage: InAppMessage?
    @State private var bannerMessage: InAppMessage?
    @State private var inlineMessages: [InAppMessage] = []

    private let userID = "user_123"

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                VStack(spacing: 10) {
                    screenPicker
                    actionButtons
                    inlineList
                    logView
                }
                .padding(.horizontal)

                if let banner = bannerMessage {
                    InAppBannerView(message: banner) { actionId in
                        Task { await handleBannerAction(banner, actionId: actionId) }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .top))
                }
            }
            .navigationTitle("In-App Demo")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear log") { log.removeAll() }
                }
            }
        }
        .onAppear {
            registerInAppListener()
            setScreen("home")
        }
        .sheet(item: $modalMessage) { message in
            InAppModalView(message: message) { actionId in
                Task { await handleModalAction(message, actionId: actionId) }
            }
        }
    }

    private var screenPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Logical screen: \(currentScreen)")
                .font(.caption)
                .foregroundColor(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(screens, id: \.self) { name in
                        Button(name) { setScreen(name) }
                            .buttonStyle(.bordered)
                            .tint(currentScreen == name ? .blue : .gray)
                    }
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            ActionButton(title: "Identify user", color: .blue) { identifyUser() }
            ActionButton(title: "Sync in-app", color: .green) {
                Task { await syncInApp() }
            }
            ActionButton(title: "Reset local in-app UI", color: .gray) {
                inlineMessages = []
                bannerMessage = nil
                modalMessage = nil
                OpenCDP.shared.inApp?.resetSession()
                appendLog("Local in-app UI reset")
            }
            ActionButton(title: "Clear identity", color: .red) {
                OpenCDP.shared.clearIdentity()
                appendLog("Identity cleared")
            }
        }
    }

    private var inlineList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Inline / inbox_card")
                .font(.headline)
            if inlineMessages.isEmpty {
                Text("No inline messages yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(inlineMessages, id: \.deliveryId) { message in
                    InAppInlineCardView(message: message) { actionId in
                        Task {
                            if let actionId {
                                await OpenCDP.shared.trackInAppClick(message, actionId: actionId)
                            } else {
                                await OpenCDP.shared.trackInAppDismiss(message, reason: .userClose)
                                inlineMessages.removeAll { $0.deliveryId == message.deliveryId }
                            }
                        }
                    }
                }
            }
        }
    }

    private var logView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(log, id: \.self) { entry in
                    Text(entry)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxHeight: 160)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func registerInAppListener() {
        OpenCDP.shared.addInAppListener { message in
            Task { @MainActor in
                await routeMessage(message)
            }
        }
    }

    private func setScreen(_ name: String) {
        currentScreen = name
        OpenCDP.shared.inApp?.setCurrentScreen(name)
        OpenCDP.shared.trackScreenView(title: name)
        appendLog("Screen: \(name)")
    }

    private func identifyUser() {
        OpenCDP.shared.identify(
            identifier: userID,
            properties: [
                "email": "user@example.com",
                "plan": "pro",
            ]
        )
        appendLog("Identified: \(userID)")
    }

    private func syncInApp() async {
        let messages = await OpenCDP.shared.syncInAppMessages(screen: currentScreen, limit: 10)
        appendLog("Synced \(messages.count) message(s)")
        for message in messages {
            await routeMessage(message)
        }
    }

    @MainActor
    private func routeMessage(_ message: InAppMessage) async {
        switch message.renderType {
        case .modal:
            modalMessage = message
            await OpenCDP.shared.trackInAppImpression(message)
            appendLog("modal: \(message.deliveryId)")
        case .banner:
            bannerMessage = message
            await OpenCDP.shared.trackInAppImpression(message)
            appendLog("banner: \(message.deliveryId)")
        case .inline, .inboxCard:
            if !inlineMessages.contains(where: { $0.deliveryId == message.deliveryId }) {
                inlineMessages.append(message)
            }
            await OpenCDP.shared.trackInAppImpression(message)
            appendLog("\(message.renderType.rawValue): \(message.deliveryId)")
        case .unknown:
            appendLog("unknown render type")
        }
    }

    private func handleModalAction(_ message: InAppMessage, actionId: String?) async {
        modalMessage = nil
        if let actionId, !actionId.isEmpty {
            await OpenCDP.shared.trackInAppClick(message, actionId: actionId)
        } else {
            await OpenCDP.shared.trackInAppDismiss(message, reason: .userClose)
        }
    }

    private func handleBannerAction(_ message: InAppMessage, actionId: String?) async {
        bannerMessage = nil
        if let actionId, !actionId.isEmpty {
            await OpenCDP.shared.trackInAppClick(message, actionId: actionId)
        } else {
            await OpenCDP.shared.trackInAppDismiss(message, reason: .userClose)
        }
    }

    private func appendLog(_ message: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        log.append("[\(ts)] \(message)")
    }
}

// MARK: - Renderers

struct InAppModalView: View {
    let message: InAppMessage
    let onClose: (String?) -> Void

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                Text("modal").font(.caption.bold()).foregroundColor(.blue)
                if let title = message.title { Text(title).font(.title2.bold()) }
                if let body = message.body { Text(body) }
                ForEach(message.ctas, id: \.id) { cta in
                    Button(cta.label) { onClose(cta.id) }
                        .buttonStyle(.borderedProminent)
                }
                Button("Dismiss") { onClose(nil) }
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("In-app")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onClose(nil) }
                }
            }
        }
    }
}

struct InAppBannerView: View {
    let message: InAppMessage
    let onAction: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("banner").font(.caption2.bold()).foregroundColor(.cyan)
            if let title = message.title { Text(title).font(.headline).foregroundColor(.white) }
            if let body = message.body { Text(body).font(.caption).foregroundColor(.white.opacity(0.9)) }
            HStack {
                if let cta = message.ctas.first {
                    Button(cta.label) { onAction(cta.id) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                Button("Close") { onAction(nil) }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(12)
        .background(Color(.darkGray))
        .cornerRadius(12)
    }
}

struct InAppInlineCardView: View {
    let message: InAppMessage
    let onAction: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.renderType.rawValue)
                .font(.caption2.bold())
                .foregroundColor(.teal)
            if let title = message.title { Text(title).font(.subheadline.bold()) }
            if let body = message.body { Text(body).font(.caption) }
            HStack {
                ForEach(message.ctas.prefix(2), id: \.id) { cta in
                    Button(cta.label) { onAction(cta.id) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                Button("Dismiss") { onAction(nil) }
                    .font(.caption)
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

extension InAppMessage: Identifiable {
    public var id: String { deliveryId }
}

#Preview {
    InAppDemoView()
}
