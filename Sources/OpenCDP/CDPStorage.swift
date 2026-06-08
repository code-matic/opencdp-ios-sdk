import Foundation

struct CDPQueuedRequest: Codable {
    let endpoint: String
    let bodyData: Data
    let identifier: String?
    var retryCount: Int
    let createdAt: Date
}

final class CDPStorage: @unchecked Sendable {
    private let defaults: UserDefaults
    private let bridgeDefaults: UserDefaults?

    private enum Keys {
        static let identifier = "com.opencdp.identifier"
        static let deviceId = "com.opencdp.device_id"
        static let requestQueue = "com.opencdp.request_queue"
        static let apnsToken = "com.opencdp.apns_token"
    }

    init(appGroup: String?) {
        if let appGroup, let groupDefaults = UserDefaults(suiteName: appGroup) {
            defaults = groupDefaults
            bridgeDefaults = groupDefaults
        } else {
            defaults = UserDefaults.standard
            bridgeDefaults = nil
        }
    }

    func setIdentifier(_ identifier: String?) {
        if let identifier {
            defaults.set(identifier, forKey: Keys.identifier)
            bridgeDefaults?.set(identifier, forKey: OpenCdpStorageKeys.userId)
        } else {
            defaults.removeObject(forKey: Keys.identifier)
            bridgeDefaults?.removeObject(forKey: OpenCdpStorageKeys.userId)
        }
    }

    func getIdentifier() -> String? {
        defaults.string(forKey: Keys.identifier)
    }

    func setDeviceId(_ deviceId: String) {
        defaults.set(deviceId, forKey: Keys.deviceId)
        bridgeDefaults?.set(deviceId, forKey: OpenCdpStorageKeys.deviceId)
    }

    func getDeviceId() -> String? {
        defaults.string(forKey: Keys.deviceId)
    }

    func setApnsToken(_ token: String) {
        defaults.set(token, forKey: Keys.apnsToken)
    }

    func getApnsToken() -> String? {
        defaults.string(forKey: Keys.apnsToken)
    }

    func saveBridgeCredentials(apiKey: String, baseUrl: String, baseUrls: [String]) {
        guard let bridgeDefaults else { return }
        bridgeDefaults.set(apiKey, forKey: OpenCdpStorageKeys.apiKey)
        bridgeDefaults.set(baseUrl, forKey: OpenCdpStorageKeys.baseUrl)
        bridgeDefaults.set(baseUrls, forKey: OpenCdpStorageKeys.baseUrls)
    }

    func clearBridgeIdentity() {
        bridgeDefaults?.removeObject(forKey: OpenCdpStorageKeys.userId)
    }

    func clearBridgeAll() {
        bridgeDefaults?.removeObject(forKey: OpenCdpStorageKeys.apiKey)
        bridgeDefaults?.removeObject(forKey: OpenCdpStorageKeys.userId)
        bridgeDefaults?.removeObject(forKey: OpenCdpStorageKeys.baseUrl)
        bridgeDefaults?.removeObject(forKey: OpenCdpStorageKeys.baseUrls)
    }

    func addToQueue(_ request: CDPQueuedRequest) {
        var queue = getQueueRaw()
        if let data = try? JSONEncoder().encode(request),
           let json = String(data: data, encoding: .utf8) {
            queue.append(json)
            defaults.set(queue, forKey: Keys.requestQueue)
        }
    }

    func peekQueue() -> CDPQueuedRequest? {
        guard let raw = getQueueRaw().first,
              let data = raw.data(using: .utf8),
              let request = try? JSONDecoder().decode(CDPQueuedRequest.self, from: data) else {
            return nil
        }
        return request
    }

    func popQueue() {
        var queue = getQueueRaw()
        if !queue.isEmpty {
            queue.removeFirst()
            defaults.set(queue, forKey: Keys.requestQueue)
        }
    }

    private func getQueueRaw() -> [String] {
        defaults.stringArray(forKey: Keys.requestQueue) ?? []
    }

    func clearIdentity() {
        defaults.removeObject(forKey: Keys.identifier)
        clearBridgeIdentity()
    }

    func clearAll() {
        defaults.removeObject(forKey: Keys.identifier)
        defaults.removeObject(forKey: Keys.deviceId)
        defaults.removeObject(forKey: Keys.requestQueue)
        defaults.removeObject(forKey: Keys.apnsToken)
        clearBridgeAll()
    }
}
