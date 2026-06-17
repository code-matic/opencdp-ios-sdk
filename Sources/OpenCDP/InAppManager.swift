import Foundation

public final class CDPInAppManager {
    protocol Callbacks: AnyObject {
        func syncMessages(screen: String, limit: Int) async -> [InAppMessage]
        func trackImpression(deliveryId: String, screen: String) async
        func trackClick(deliveryId: String, actionId: String, screen: String) async
        func trackDismiss(deliveryId: String, reason: String, screen: String) async
        func createRealtimeClient(personId: String, onSync: @escaping () -> Void) -> InAppRealtimeClient
    }

    private let config: OpenCDPConfig
    private weak var callbacks: Callbacks?
    private var listeners: [InAppMessageListener] = []
    private var deliveryState: [String: DeliveryState] = [:]
    private var dispatchedDeliveryIds = Set<String>()
    private var currentScreen = "unknown"
    private var identity: String?
    private var realtimeClient: InAppRealtimeClient?
    private var pollTask: Task<Void, Never>?
    private var syncInFlight = false
    private var pendingSyncReason: String?
    private var disposed = false

    init(config: OpenCDPConfig, callbacks: Callbacks) {
        self.config = config
        self.callbacks = callbacks
    }

    func addListener(_ listener: @escaping InAppMessageListener) {
        listeners.append(listener)
    }

    func setCurrentScreen(_ screen: String, triggerSync: Bool = true) {
        guard !screen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              currentScreen != screen else { return }
        currentScreen = screen
        if config.enableInAppMessages, triggerSync {
            syncNow(reason: "screen_change")
        }
    }

    func resetSession() {
        deliveryState.removeAll()
        dispatchedDeliveryIds.removeAll()
    }

    func setActiveIdentity(_ identity: String?) {
        guard !disposed, config.enableInAppMessages else { return }
        let trimmed = identity?.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = trimmed.flatMap { $0.isEmpty ? nil : $0 }
        guard next != self.identity else { return }
        self.identity = next
        resetSession()
        shutdownRealtime()
        guard let next else {
            stopPolling()
            return
        }
        if config.enableInAppRealtime {
            startRealtime(next)
            stopPolling()
        } else {
            startPolling()
        }
    }

    func startIfEnabled(initialIdentity: String?) {
        guard config.enableInAppMessages, !disposed else { return }
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            syncNow(reason: "initial")
        }
        if let initialIdentity { setActiveIdentity(initialIdentity) }
        if !config.enableInAppRealtime { startPolling() }
    }

    func syncNow(reason: String = "manual") {
        Task { await syncNowInternal(reason: reason) }
    }

    func trackImpression(_ message: InAppMessage) async {
        guard !disposed else { return }
        var state = deliveryState[message.deliveryId] ?? DeliveryState()
        state.impressionsTotal += 1
        state.lastShownAt = Date()
        deliveryState[message.deliveryId] = state
        await callbacks?.trackImpression(deliveryId: message.deliveryId, screen: currentScreen)
    }

    func trackClick(_ message: InAppMessage, actionId: String) async {
        guard !disposed else { return }
        await callbacks?.trackClick(deliveryId: message.deliveryId, actionId: actionId, screen: currentScreen)
    }

    func trackDismiss(_ message: InAppMessage, reason: InAppDismissReason = .unknown) async {
        guard !disposed else { return }
        var state = deliveryState[message.deliveryId] ?? DeliveryState()
        state.dismissed = true
        deliveryState[message.deliveryId] = state
        await callbacks?.trackDismiss(deliveryId: message.deliveryId, reason: reason.rawValue, screen: currentScreen)
    }

    func dispose() {
        disposed = true
        stopPolling()
        shutdownRealtime()
        listeners.removeAll()
    }

    private func syncNowInternal(reason: String) async {
        guard !disposed, config.enableInAppMessages else { return }
        if syncInFlight {
            pendingSyncReason = pickHigherPriorityReason(pendingSyncReason, reason)
            return
        }
        syncInFlight = true
        var currentReason = reason
        defer { syncInFlight = false }
        while true {
            await runSync(currentReason)
            guard let next = pendingSyncReason else { break }
            pendingSyncReason = nil
            currentReason = next
        }
    }

    private func runSync(_ reason: String) async {
        guard let callbacks else { return }
        let messages = await callbacks.syncMessages(
            screen: currentScreen,
            limit: min(max(config.inAppSyncLimit, 1), 50)
        )
        let eligible = arbitrate(messages)
        for message in eligible where !dispatchedDeliveryIds.contains(message.deliveryId) {
            dispatchedDeliveryIds.insert(message.deliveryId)
            emit(message)
        }
    }

    private func arbitrate(_ messages: [InAppMessage]) -> [InAppMessage] {
        let now = Date()
        return messages.filter { message in
            if message.isExpired { return false }
            guard let state = deliveryState[message.deliveryId] else { return true }
            if state.dismissed { return false }
            guard let persistence = message.persistence else { return true }
            if let maxTotal = persistence.maxImpressionsTotal, state.impressionsTotal >= maxTotal { return false }
            if let minInterval = persistence.minIntervalSeconds,
               let lastShown = state.lastShownAt,
               now.timeIntervalSince(lastShown) < Double(minInterval) { return false }
            return true
        }
    }

    private func emit(_ message: InAppMessage) {
        listeners.forEach { $0(message) }
    }

    private func startRealtime(_ personId: String) {
        guard let callbacks else { return }
        shutdownRealtime()
        let client = callbacks.createRealtimeClient(personId: personId) { [weak self] in
            self?.syncNow(reason: "realtime_event")
        }
        realtimeClient = client
        client.start()
    }

    private func shutdownRealtime() {
        realtimeClient?.stop()
        realtimeClient = nil
    }

    private func startPolling() {
        stopPolling()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64((self?.config.inAppPollInterval ?? 30) * 1_000_000_000))
                self?.syncNow(reason: "poll")
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func pickHigherPriorityReason(_ current: String?, _ next: String) -> String {
        guard let current else { return next }
        func weight(_ r: String) -> Int {
            switch r {
            case "realtime_event": return 100
            case "realtime_connected": return 90
            case "manual": return 80
            case "initial": return 70
            case "screen_change": return 60
            case "poll": return 10
            default: return 50
            }
        }
        return weight(next) > weight(current) ? next : current
    }

    private struct DeliveryState {
        var impressionsTotal = 0
        var lastShownAt: Date?
        var dismissed = false
    }
}
