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
    private let queue = DispatchQueue(label: "com.opencdp.sdk.queue")
    
    /// Current user identifier
    public private(set) var currentUserId: String?
    
    private init() {}
    
    /// Initialize the SDK with the provided configuration.
    ///
    /// - Parameter config: The configuration object
    public func initialize(config: OpenCDPConfig) {
        self.config = config
        self.httpClient = CDPHttpClient(config: config)
        self.isInitialized = true
        
        if config.debug {
            print("🚀 OpenCDP SDK Initialized")
        }
        
        if config.trackApplicationLifecycleEvents {
            setupLifecycleTracking()
        }
    }
    
    // MARK: - API Calls
    
    private func sendRequest(endpoint: String, body: [String: Any]) {
        guard let client = httpClient else { return }
        
        Task {
            do {
                if let response = try await client.post(endpoint: endpoint, body: body) {
                    logDebug("✅ Success [\(endpoint)]: \(response)")
                } else {
                    logDebug("✅ Success [\(endpoint)]: No content")
                }
            } catch {
                if let cdpError = error as? CDPError {
                    switch cdpError {
                    case .networkError(let msg): logError("❌ Network Error [\(endpoint)]: \(msg)")
                    case .serverError(let code, let message): logError("❌ Server Error [\(endpoint)]: Status \(code) - \(message)")
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
        logDebug("Identifying user: \(identifier)")
        
        sendRequest(endpoint: "/v1/persons/identify", body: [
            "identifier": identifier,
            "properties": properties, // Flutter uses 'properties', I was using 'traits' (common in Segment but need CD parity) -> checking Flutter line 244: 'properties': normalizedProps. OK.
            // Wait, my previous code had "traits". Flutter has "properties".
            // I should use "properties".
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
        
        var body = properties
        body["eventName"] = eventName
        body["identifier"] = currentUserId
        body["timestamp"] = Date().timeIntervalSince1970
        // Flutter sends: identifier, eventName, properties (nested?)
        // Let's check Flutter line 298.
        /*
          {
          'identifier': _currentIdentifier,
          'eventName': eventName,
          'properties': normalizedProps,
        },
        */
        // My previous code was merging properties into the body top-level. 
        // Flutter sends them as a NESTED "properties" object!
        
        let payload: [String: Any] = [
            "identifier": currentUserId ?? "",
            "eventName": eventName,
            "properties": properties,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendRequest(endpoint: "/v1/persons/track", body: payload)
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
        
        sendRequest(endpoint: "/v1/persons/registerDevice", body: [
            "deviceToken": token,
            "identifier": currentUserId ?? "",
            "platform": "ios"
        ])
    }
    
    /// Clear the current user identity and reset SDK state.
    public func clearIdentity() {
        self.currentUserId = nil
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
