import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Main SDK class for Open CDP
public class OpenCDP {
    /// Singleton instance
    public static let shared = OpenCDP()
    
    private var config: OpenCDPConfig?
    private var httpClient: CDPHttpClient?
    private var isInitialized = false
    private var storage: CDPStorage?
    
    /// Current user identifier
    public private(set) var currentUserId: String?
    
    private init() {}
    
    /// Initialize the SDK with the provided configuration.
    ///
    /// - Parameter config: The configuration object
    public func initialize(config: OpenCDPConfig) {
        self.config = config
        self.httpClient = CDPHttpClient(config: config)
        self.storage = CDPStorage(appGroup: config.iOSAppGroup)
        self.isInitialized = true
        
        // Restore previous identifier if available
        if let savedId = storage?.getIdentifier() {
            self.currentUserId = savedId
            logDebug("Restored identity: \(savedId)")
        }
        
        if config.debug {
            print("🚀 OpenCDP SDK Initialized")
        }
        
        if config.trackApplicationLifecycleEvents {
            setupLifecycleTracking()
        }
        
        // Attempt to flush offline queue on startup
        flushQueue()
    }
    
    // MARK: - API Calls
    
    private func sendRequest(endpoint: String, body: [String: Any], isRetry: Bool = false) {
        guard let client = httpClient else { return }
        
        Task {
            do {
                if let response = try await client.post(endpoint: endpoint, body: body) {
                    logDebug("✅ Success [\(endpoint)]: \(response)")
                } else {
                    logDebug("✅ Success [\(endpoint)]: No content")
                }
                
                // If successful and not a retry, try to flush the queue
                if !isRetry {
                    flushQueue()
                }
            } catch {
                if let cdpError = error as? CDPError {
                    switch cdpError {
                    case .networkError(let msg):
                        handleFailure(endpoint: endpoint, body: body, message: "Network Error: \(msg)", isRetry: isRetry)
                    case .serverError(let code, let message):
                        if code >= 500 {
                            handleFailure(endpoint: endpoint, body: body, message: "Server Error (\(code)): \(message)", isRetry: isRetry)
                        } else {
                            logError("❌ Client/Validation Error [\(endpoint)]: Status \(code) - \(message)")
                        }
                    case .decodingError: logError("❌ Decoding Error [\(endpoint)]")
                    case .invalidInput: logError("❌ Invalid Input [\(endpoint)]")
                    case .initializationError: logError("❌ Initialization Error")
                    }
                } else {
                    logError("❌ Unknown Error [\(endpoint)]: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleFailure(endpoint: String, body: [String: Any], message: String, isRetry: Bool) {
        logError("❌ \(message) [\(endpoint)]")
        if !isRetry {
            logDebug("Queueing request for later retry: \(endpoint)")
            storage?.addToQueue(endpoint: endpoint, body: body)
        }
    }
    
    private func flushQueue() {
        guard let storage = storage, let client = httpClient else { return }
        
        let queuedItems = storage.getQueue()
        guard !queuedItems.isEmpty else { return }
        
        logDebug("Flushing \(queuedItems.count) queued requests")
        
        // Process ONLY the first item. If successful, it recursively calls flushQueue via sendRequest.
        // This prevents overwhelming the server and maintains order.
        if let firstItemJson = queuedItems.first,
           let data = firstItemJson.data(using: .utf8),
           let item = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let endpoint = item["endpoint"] as? String,
           let body = item["body"] as? [String: Any] {
            
            Task {
                do {
                    _ = try await client.post(endpoint: endpoint, body: body)
                    logDebug("✅ Successfully flushed queued request: \(endpoint)")
                    storage.popQueue()
                    // Recurse to process the next item
                    self.flushQueue()
                } catch {
                    logDebug("⚠️ Failed to flush queued request, will retry later: \(error)")
                }
            }
        } else if !queuedItems.isEmpty {
            // Remove corrupt item
            storage.popQueue()
            flushQueue()
        }
    }
    
    /// Identify a user with a unique identifier and optional properties.
    ///
    /// - Parameters:
    ///   - identifier: Unique user ID (NOT an email)
    ///   - properties: Optional user properties
    public func identify(identifier: String, properties: [String: Any] = [:]) {
        guard isInitialized else {
            logError("SDK not initialized. Call initialize() first.")
            return
        }
        
        self.currentUserId = identifier
        storage?.setIdentifier(identifier)
        logDebug("Identifying user: \(identifier)")
        
        sendRequest(endpoint: "/identify", body: [
            "identifier": identifier,
            "traits": properties,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track a custom event.
    ///
    /// - Parameters:
    ///   - eventName: Name of the event
    ///   - properties: Optional event properties
    public func track(eventName: String, properties: [String: Any] = [:]) {
        guard isInitialized else { return }
        logDebug("Tracking event: \(eventName)")
        
        let payload: [String: Any] = [
            "identifier": currentUserId ?? "",
            "event": eventName,
            "properties": properties,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendRequest(endpoint: "/track", body: payload)
    }
    
    /// Track a screen view manually.
    ///
    /// - Parameters:
    ///   - title: Screen name
    ///   - properties: Optional properties
    public func trackScreenView(title: String, properties: [String: Any] = [:]) {
        guard isInitialized else { return }
        logDebug("Screen view: \(title)")
        
        // Screens are tracked as events
        track(eventName: "screen_view", properties: properties.merging(["screen": title]) { (_, new) in new })
    }
    
    /// Register a device token for push notifications.
    ///
    /// - Parameter token: The APNs device token as a hex string
    public func registerDeviceToken(_ token: String) {
        guard isInitialized else { return }
        logDebug("Registering device token: \(token)")
        
        sendRequest(endpoint: "/device", body: [
            "device_token": token,
            "identifier": currentUserId ?? "",
            "os": "ios"
        ])
    }
    
    /// Clear the current user identity and reset SDK state.
    public func clearIdentity() {
        self.currentUserId = nil
        storage?.setIdentifier(nil)
        logDebug("Identity cleared")
    }
    
    // MARK: - internal helpers
    
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
        #endif
    }
    
    @objc private func appDidBecomeActive() {
        logDebug("App became active")
        track(eventName: "application_opened")
    }
    
    @objc private func appDidEnterBackground() {
        logDebug("App entered background")
        track(eventName: "application_backgrounded")
    }
    
    private func logDebug(_ message: String) {
        if config?.debug == true {
            let formattedMessage = "OpenCDP [DEBUG]: \(message)"
            print(formattedMessage)
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenCDPLog"),
                object: nil,
                userInfo: ["message": formattedMessage]
            )
        }
    }
    
    private func logError(_ message: String) {
        let formattedMessage = "OpenCDP [ERROR]: \(message)"
        print(formattedMessage)
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenCDPLog"),
            object: nil,
            userInfo: ["message": formattedMessage]
        )
    }
}
