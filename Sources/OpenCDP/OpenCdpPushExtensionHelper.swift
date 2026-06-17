import Foundation
import UserNotifications
import os.log

public class OpenCdpPushExtensionHelper {
    private static let maxRetries = 3
    private static let baseRetryDelayMs: UInt64 = 1000

    public static func didReceiveNotificationExtensionRequest(
        _ request: UNNotificationRequest,
        appGroup: String,
        completion: @escaping (UNNotificationContent) -> Void
    ) {
        let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
            ?? UNMutableNotificationContent()
        let userInfo = request.content.userInfo

        guard let deliveryMessageId = userInfo["delivery_message_id"] as? String,
              let deliverySendContext = userInfo["delivery_send_context"] as? String else {
            completion(request.content)
            return
        }

        guard let apiKey = readApiKey(appGroup: appGroup) else {
            completion(request.content)
            return
        }

        let personId = (userInfo["person_id"] as? String) ?? readUserId(appGroup: appGroup)
        guard let personId else {
            completion(request.content)
            return
        }

        let deliverySendContextId = userInfo["delivery_send_context_id"] as? String ?? ""
        reportPushStatus(
            deliveryMessageId: deliveryMessageId,
            personId: personId,
            deliverySendContext: deliverySendContext,
            deliverySendContextId: deliverySendContextId,
            status: "delivered",
            apiKey: apiKey,
            appGroup: appGroup,
            completion: { completion(bestAttemptContent) }
        )
    }

    static func resolveGatewayHosts(appGroup: String) -> [String] {
        if let stored = readBaseUrls(appGroup: appGroup), !stored.isEmpty {
            return dedupeHosts(stored)
        }
        if let single = readBaseUrl(appGroup: appGroup), !single.isEmpty {
            return dedupeHosts([single] + CdpGatewayUrls.defaultFallbackBaseUrls)
        }
        return CdpGatewayUrls.resolveAllBaseUrls(primaryOverride: nil, fallbackOverrides: nil)
    }

    private static func reportPushStatus(
        deliveryMessageId: String,
        personId: String,
        deliverySendContext: String,
        deliverySendContextId: String,
        status: String,
        apiKey: String,
        appGroup: String,
        completion: @escaping () -> Void
    ) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let body: [String: Any] = [
            "message_id": deliveryMessageId,
            "person_id": personId,
            "send_context": deliverySendContext,
            "send_context_id": deliverySendContextId,
            "status": status,
            "ts": formatter.string(from: Date()),
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            completion()
            return
        }
        postWithFailover(apiKey: apiKey, jsonData: jsonData, hosts: resolveGatewayHosts(appGroup: appGroup), retryCount: 0, completion: completion)
    }

    private static func postWithFailover(
        apiKey: String,
        jsonData: Data,
        hosts: [String],
        retryCount: Int,
        completion: @escaping () -> Void
    ) {
        tryNextHost(apiKey: apiKey, jsonData: jsonData, hosts: hosts, hostIndex: 0, retryCount: retryCount, completion: completion)
    }

    private static func tryNextHost(
        apiKey: String,
        jsonData: Data,
        hosts: [String],
        hostIndex: Int,
        retryCount: Int,
        completion: @escaping () -> Void
    ) {
        if hostIndex >= hosts.count {
            if retryCount >= maxRetries {
                completion()
                return
            }
            let delayMs = baseRetryDelayMs * UInt64(pow(2.0, Double(retryCount))) + UInt64.random(in: 0..<baseRetryDelayMs)
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(delayMs) / 1000.0) {
                postWithFailover(apiKey: apiKey, jsonData: jsonData, hosts: hosts, retryCount: retryCount + 1, completion: completion)
            }
            return
        }

        let root = CdpGatewayUrls.normalizeBaseUrl(hosts[hostIndex])
        guard let url = URL(string: "\(root)\(CDPEndpoints.notificationMetrics)") else {
            tryNextHost(apiKey: apiKey, jsonData: jsonData, hosts: hosts, hostIndex: hostIndex + 1, retryCount: retryCount, completion: completion)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), error == nil {
                completion()
                return
            }
            tryNextHost(apiKey: apiKey, jsonData: jsonData, hosts: hosts, hostIndex: hostIndex + 1, retryCount: retryCount, completion: completion)
        }.resume()
    }

    private static func readApiKey(appGroup: String) -> String? {
        UserDefaults(suiteName: appGroup)?.string(forKey: OpenCdpStorageKeys.apiKey)
    }

    private static func readUserId(appGroup: String) -> String? {
        UserDefaults(suiteName: appGroup)?.string(forKey: OpenCdpStorageKeys.userId)
    }

    private static func readBaseUrl(appGroup: String) -> String? {
        UserDefaults(suiteName: appGroup)?.string(forKey: OpenCdpStorageKeys.baseUrl)
    }

    private static func readBaseUrls(appGroup: String) -> [String]? {
        UserDefaults(suiteName: appGroup)?.stringArray(forKey: OpenCdpStorageKeys.baseUrls)
    }

    private static func dedupeHosts(_ hosts: [String]) -> [String] {
        var seen = Set<String>()
        return hosts.compactMap {
            let normalized = CdpGatewayUrls.normalizeBaseUrl($0)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { return nil }
            return normalized
        }
    }
}
