import Foundation
#if canImport(UIKit)
import UIKit
import ObjectiveC
#endif

public final class OpenCDP: @unchecked Sendable {
    public static let shared = OpenCDP()

    private var config: OpenCDPConfig?
    private var httpClient: CDPHttpClient?
    private var storage: CDPStorage?
    private var inAppManager: CDPInAppManager?
    #if canImport(UIKit)
    private var screenTracker: ScreenTracker?
    #endif
    private var wasBackgrounded = false
    private var initialized = false

    public private(set) var currentUserId: String?

    public var inApp: CDPInAppManager? { inAppManager }

    private init() {}

    public func initialize(config: OpenCDPConfig, shouldReinitialize: Bool = false) {
        if initialized, !shouldReinitialize { return }
        if initialized, shouldReinitialize {
            inAppManager?.dispose()
            inAppManager = nil
        }

        self.config = config
        self.storage = CDPStorage(appGroup: config.iOSAppGroup)
        self.httpClient = CDPHttpClient(config: config, storage: storage!)
        bootstrapDeviceId()
        persistBridgeCredentials()

        if let savedId = storage?.getIdentifier() {
            currentUserId = savedId
        }

        if config.sendToCustomerIo, let cio = config.customerIo {
            CustomerIOWrapper.initialize(config: cio)
        }

        if config.trackApplicationLifecycleEvents {
            setupLifecycleTracking()
        }

        #if canImport(UIKit)
        if config.autoTrackScreens {
            ScreenTracker.swizzleIfNeeded()
            screenTracker = ScreenTracker(openCDP: self)
            screenTracker?.start()
        }
        #endif

        let callbacks = InAppCallbacks(host: self)
        inAppManager = CDPInAppManager(config: config, callbacks: callbacks)
        inAppManager?.startIfEnabled(initialIdentity: currentUserId)

        Task { await httpClient?.flushQueue() }

        if config.autoTrackDeviceAttributes {
            Task { await registerDeviceToken(storage?.getApnsToken()) }
        }

        initialized = true
        logDebug("OpenCDP SDK Initialized")
    }

    public func identify(identifier: String, properties: [String: Any] = [:], customerIoId: String? = nil) {
        Task {
            guard await ensureInitialized() else { return }
            guard validateIdentifier(identifier) else { return }
            currentUserId = identifier
            storage?.setIdentifier(identifier)
            try? await httpClient?.post(
                endpoint: CDPEndpoints.identify,
                body: ["identifier": identifier, "properties": properties],
                identifier: identifier
            )
            inAppManager?.setActiveIdentity(identifier)
            if config?.sendToCustomerIo == true {
                CustomerIOWrapper.identify(userId: customerIoId ?? identifier, traits: properties)
            }
        }
    }

    public func track(eventName: String, properties: [String: Any] = [:]) {
        Task {
            guard await ensureInitialized() else { return }
            guard validateEventName(eventName) else { return }
            try? await httpClient?.post(
                endpoint: CDPEndpoints.track,
                body: [
                    "identifier": currentIdentifier(),
                    "eventName": eventName,
                    "properties": properties,
                ],
                identifier: currentIdentifier()
            )
            if config?.sendToCustomerIo == true {
                CustomerIOWrapper.track(eventName: eventName, properties: properties)
            }
        }
    }

    public func trackScreenView(title: String, properties: [String: Any] = [:]) {
        Task {
            guard await ensureInitialized() else { return }
            var merged = properties
            merged["screen"] = title
            try? await httpClient?.post(
                endpoint: CDPEndpoints.track,
                body: [
                    "identifier": currentIdentifier(),
                    "eventName": "screen_view",
                    "properties": merged,
                ],
                identifier: currentIdentifier()
            )
            inAppManager?.setCurrentScreen(title)
            if config?.sendToCustomerIo == true {
                CustomerIOWrapper.screen(title: title, properties: merged)
            }
        }
    }

    public func trackLifecycleEvent(eventName: String, properties: [String: Any] = [:]) {
        track(eventName: eventName, properties: properties)
    }

    public func registerDeviceToken(_ token: String?) {
        Task { await registerDeviceTokenInternal(token) }
    }

    public func handleForegroundPushDelivery(_ data: [String: String]) {
        Task { await handlePushMetric(status: "delivered", data: data) }
    }

    public func handleBackgroundPushDelivery(_ data: [String: String]) {
        Task { await handlePushMetric(status: "delivered", data: data) }
    }

    public func handlePushNotificationOpen(_ data: [String: String]) {
        Task {
            let actionId = OpenCDPPushPayload.resolveActionId(data)
            let status = actionId != nil ? "clicked" : "opened"
            await handlePushMetric(status: status, data: data, actionId: actionId)
        }
    }

    public func clearIdentity() {
        Task {
            guard await ensureInitialized() else { return }
            await httpClient?.flushQueue()
            currentUserId = nil
            storage?.clearIdentity()
            inAppManager?.setActiveIdentity(nil)
            inAppManager?.resetSession()
            if config?.sendToCustomerIo == true {
                CustomerIOWrapper.clearIdentify()
            }
            logDebug("Identity cleared")
        }
    }

    public func addInAppListener(_ listener: @escaping InAppMessageListener) {
        inAppManager?.addListener(listener)
    }

    public func syncInAppMessages(screen: String? = nil, limit: Int? = nil) async -> [InAppMessage] {
        guard await ensureInitialized() else { return [] }
        return await syncInAppMessagesInternal(screen: screen, limit: limit)
    }

    public func trackInAppImpression(_ message: InAppMessage) async {
        await inAppManager?.trackImpression(message)
    }

    public func trackInAppClick(_ message: InAppMessage, actionId: String) async {
        await inAppManager?.trackClick(message, actionId: actionId)
    }

    public func trackInAppDismiss(_ message: InAppMessage, reason: InAppDismissReason = .unknown) async {
        await inAppManager?.trackDismiss(message, reason: reason)
    }

    func syncInAppMessagesInternal(screen: String?, limit: Int?) async -> [InAppMessage] {
        guard let httpClient, let config else { return [] }
        let resolvedScreen = screen ?? "unknown"
        let resolvedLimit = min(max(limit ?? config.inAppSyncLimit, 1), 50)
        var query: [String: Any] = [
            "person_id": currentIdentifier(),
            "screen": resolvedScreen,
            "platform": config.inAppPlatformOverride ?? "ios",
            "limit": resolvedLimit,
            "tz_offset_minutes": TimeZone.current.secondsFromGMT() / 60,
        ]
        if let appVersion = config.inAppAppVersionOverride, !appVersion.isEmpty {
            query["app_version"] = appVersion
        }
        guard let response = try? await httpClient.get(endpoint: CDPEndpoints.inAppSync, query: query),
              let data = response["data"] as? [String: Any],
              let rawMessages = data["messages"] as? [[String: Any]] else {
            return []
        }
        return rawMessages.map(InAppMessage.fromJson)
    }

    private func registerDeviceTokenInternal(_ token: String?) async {
        guard await ensureInitialized() else { return }
        guard IdentifierValidator.isValidPushToken(token) else {
            logError("apnToken cannot be empty")
            return
        }
        storage?.setApnsToken(token!)
        #if canImport(UIKit)
        let attrs = deviceAttributes()
        let identifier = currentIdentifier()
        let deviceIdInput = "\(attrs["device_model"] ?? "")-\(attrs["device_manufacturer"] ?? "")-\(identifier)"
        let deviceId = HashGenerator.generateMd5Hash(deviceIdInput)
        try? await httpClient?.post(
            endpoint: CDPEndpoints.registerDevice,
            body: [
                "identifier": identifier,
                "deviceId": deviceId,
                "name": attrs["device_manufacturer"] ?? "Apple",
                "platform": "ios",
                "osVersion": attrs["os_version"] ?? "",
                "model": attrs["device_model"] ?? "",
                "apnToken": token!,
                "appVersion": attrs["app_version"] ?? "",
                "attributes": attrs,
            ],
            identifier: identifier
        )
        if config?.sendToCustomerIo == true {
            CustomerIOWrapper.registerDeviceToken(token!)
        }
        #endif
    }

    private func handlePushMetric(status: String, data: [String: String], actionId: String? = nil) async {
        guard let config, let httpClient else { return }
        _ = await PushNotificationTracker.sendMetric(
            apiKey: config.cdpApiKey,
            baseUrls: httpClient.baseUrls,
            status: status,
            data: data,
            personId: currentUserId ?? storage?.getIdentifier(),
            actionId: actionId
        )
    }

    private func bootstrapDeviceId() {
        guard storage?.getDeviceId() == nil else { return }
        #if canImport(UIKit)
        if let idfv = UIDevice.current.identifierForVendor?.uuidString {
            storage?.setDeviceId(idfv)
        }
        #endif
    }

    #if canImport(UIKit)
    private func deviceAttributes() -> [String: Any] {
        let device = UIDevice.current
        let info = Bundle.main.infoDictionary
        return [
            "device_manufacturer": "Apple",
            "device_model": device.model,
            "os_name": device.systemName,
            "os_version": device.systemVersion,
            "app_version": info?["CFBundleShortVersionString"] as? String ?? "",
            "app_build": info?["CFBundleVersion"] as? String ?? "",
            "app_package": Bundle.main.bundleIdentifier ?? "",
        ]
    }
    #endif

    private func persistBridgeCredentials() {
        guard let config, let httpClient, let storage else { return }
        storage.saveBridgeCredentials(
            apiKey: config.cdpApiKey,
            baseUrl: httpClient.baseUrls.first ?? CDPEndpoints.baseURL,
            baseUrls: httpClient.baseUrls
        )
    }

    private func currentIdentifier() -> String {
        currentUserId ?? storage?.getDeviceId() ?? storage?.getIdentifier() ?? "unknown"
    }

    private func setupLifecycleTracking() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        #endif
    }

    #if canImport(UIKit)
    @objc private func appDidBecomeActive() {
        if wasBackgrounded {
            trackLifecycleEvent(eventName: "App_foregrounded", properties: ["timestamp": ISO8601DateFormatter().string(from: Date())])
            wasBackgrounded = false
        }
        trackLifecycleEvent(eventName: "App_resumed", properties: ["timestamp": ISO8601DateFormatter().string(from: Date())])
    }

    @objc private func appDidEnterBackground() {
        wasBackgrounded = true
        trackLifecycleEvent(eventName: "App_backgrounded", properties: ["timestamp": ISO8601DateFormatter().string(from: Date())])
    }

    @objc private func appWillResignActive() {
        trackLifecycleEvent(eventName: "App_inactive", properties: ["timestamp": ISO8601DateFormatter().string(from: Date())])
    }
    #endif

    @discardableResult
    private func ensureInitialized() async -> Bool {
        guard initialized, config != nil, httpClient != nil else {
            logError("SDK not initialized. Call initialize() first.")
            return false
        }
        return true
    }

    private func validateIdentifier(_ identifier: String) -> Bool {
        guard IdentifierValidator.isValidIdentifier(identifier) else {
            let message = identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Identifier cannot be empty"
                : "Identifier cannot be an email address"
            logError(message)
            return false
        }
        return true
    }

    private func validateEventName(_ eventName: String) -> Bool {
        guard IdentifierValidator.isValidEventName(eventName) else {
            logError("Event name cannot be empty")
            return false
        }
        return true
    }

    private func logDebug(_ message: String) {
        if config?.debug == true { print("OpenCDP [DEBUG]: \(message)") }
    }

    private func logError(_ message: String) {
        print("OpenCDP [ERROR]: \(message)")
    }

    private final class InAppCallbacks: CDPInAppManager.Callbacks {
        weak var host: OpenCDP?
        init(host: OpenCDP) { self.host = host }

        func syncMessages(screen: String, limit: Int) async -> [InAppMessage] {
            await host?.syncInAppMessagesInternal(screen: screen, limit: limit) ?? []
        }

        func trackImpression(deliveryId: String, screen: String) async {
            guard let host, let httpClient = host.httpClient else { return }
            try? await httpClient.post(
                endpoint: CDPEndpoints.inAppImpression(deliveryId),
                body: [
                    "person_id": host.currentIdentifier(),
                    "screen": screen,
                    "platform": host.config?.inAppPlatformOverride ?? "ios",
                    "ts": ISO8601DateFormatter().string(from: Date()),
                ],
                identifier: host.currentIdentifier()
            )
        }

        func trackClick(deliveryId: String, actionId: String, screen: String) async {
            guard let host, let httpClient = host.httpClient else { return }
            try? await httpClient.post(
                endpoint: CDPEndpoints.inAppClick(deliveryId),
                body: [
                    "person_id": host.currentIdentifier(),
                    "screen": screen,
                    "action_id": actionId,
                    "ts": ISO8601DateFormatter().string(from: Date()),
                ],
                identifier: host.currentIdentifier()
            )
        }

        func trackDismiss(deliveryId: String, reason: String, screen: String) async {
            guard let host, let httpClient = host.httpClient else { return }
            try? await httpClient.post(
                endpoint: CDPEndpoints.inAppDismiss(deliveryId),
                body: [
                    "person_id": host.currentIdentifier(),
                    "screen": screen,
                    "reason": reason,
                    "ts": ISO8601DateFormatter().string(from: Date()),
                ],
                identifier: host.currentIdentifier()
            )
        }

        func createRealtimeClient(personId: String, onSync: @escaping () -> Void) -> InAppRealtimeClient {
            let client = InAppRealtimeClient(
                httpClient: host!.httpClient!,
                personId: personId,
                debug: host?.config?.debug == true,
                maxBackoff: host?.config?.inAppRealtimeMaxBackoff ?? 30,
                staleTimeout: host?.config?.inAppRealtimeStaleTimeout ?? 60
            )
            client.onSyncRequested = onSync
            return client
        }
    }
}
