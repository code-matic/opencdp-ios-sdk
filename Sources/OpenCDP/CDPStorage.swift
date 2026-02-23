import Foundation

/**
 * Manages persistent storage for the iOS SDK using UserDefaults.
 * Handles user identity, configuration, and the offline request queue.
 */
internal final class CDPStorage: Sendable {
    
    private let defaults: UserDefaults
    private let suiteName: String?
    
    private enum Keys {
        static let identifier = "com.opencdp.identifier"
        static let requestQueue = "com.opencdp.request_queue"
    }
    
    init(appGroup: String? = nil) {
        self.suiteName = appGroup
        if let appGroup = appGroup, let groupDefaults = UserDefaults(suiteName: appGroup) {
            self.defaults = groupDefaults
        } else {
            self.defaults = UserDefaults.standard
        }
    }
    
    /// Saves the user identifier.
    func setIdentifier(_ identifier: String?) {
        defaults.set(identifier, forKey: Keys.identifier)
    }
    
    /// Retrieves the user identifier.
    func getIdentifier() -> String? {
        return defaults.string(forKey: Keys.identifier)
    }
    
    /// Adds a request payload to the persistent queue.
    func addToQueue(endpoint: String, body: [String: Any]) {
        var queue = getQueue()
        let item: [String: Any] = [
            "endpoint": endpoint,
            "body": body,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: item),
           let jsonString = String(data: data, encoding: .utf8) {
            queue.append(jsonString)
            saveQueue(queue)
        }
    }
    
    /// Retrieves the current offline queue.
    func getQueue() -> [String] {
        return defaults.stringArray(forKey: Keys.requestQueue) ?? []
    }
    
    /// Removes the first item from the queue.
    func popQueue() {
        var queue = getQueue()
        if !queue.isEmpty {
            queue.removeFirst()
            saveQueue(queue)
        }
    }
    
    private func saveQueue(_ queue: [String]) {
        defaults.set(queue, forKey: Keys.requestQueue)
    }
    
    /// Clears all SDK storage.
    func clear() {
        defaults.removeObject(forKey: Keys.identifier)
        defaults.removeObject(forKey: Keys.requestQueue)
    }
}
