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
        log("Push notification received in extension")
        let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
            ?? UNMutableNotificationContent()
        let userInfo = request.content.userInfo

        // Always enrich with image first — independent of delivery metric prerequisites.
        attachImageIfPresent(userInfo: userInfo, to: bestAttemptContent)

        // Deliver enriched content immediately so display is not blocked by metrics.
        completion(bestAttemptContent)

        guard let deliveryMessageId = userInfo["delivery_message_id"] as? String,
              let deliverySendContext = userInfo["delivery_send_context"] as? String else {
            log("Missing delivery tracking info. Metric skipped.")
            return
        }

        guard let apiKey = readApiKey(appGroup: appGroup) else {
            log("API Key not found. Metric skipped.")
            return
        }

        let personIdFromPayload = userInfo["person_id"] as? String
        let personId = personIdFromPayload ?? readUserId(appGroup: appGroup)
        guard let personId else {
            log("Could not find person_id. Metric skipped.")
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
            appGroup: appGroup
        ) {
            // Fire-and-forget; notification already displayed.
        }
    }

    public static func normalizeImageUrl(_ url: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        return "https://\(trimmed)"
    }

    public static func parseImageUrl(from userInfo: [AnyHashable: Any]) -> String? {
        guard let raw = userInfo["image_url"] as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : normalizeImageUrl(trimmed)
    }

    public static func parseImageUrl(_ data: [String: String]) -> String? {
        guard let raw = data["image_url"] else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : normalizeImageUrl(trimmed)
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

    private static func attachImageIfPresent(
        userInfo: [AnyHashable: Any],
        to content: UNMutableNotificationContent
    ) {
        guard let imageUrl = parseImageUrl(from: userInfo),
              let url = URL(string: imageUrl) else {
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        let semaphore = DispatchSemaphore(value: 0)
        var attachment: UNNotificationAttachment?

        let task = URLSession.shared.downloadTask(with: request) { location, response, error in
            defer { semaphore.signal() }

            guard let location = location, error == nil else { return }
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                return
            }

            let fileExtension = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)

            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: location, to: destination)
                attachment = try UNNotificationAttachment(
                    identifier: "opencdp_image",
                    url: destination,
                    options: nil
                )
            } catch {
                log("Failed to attach push image: \(error.localizedDescription)")
            }
        }
        task.resume()

        if semaphore.wait(timeout: .now() + 8) == .timedOut {
            task.cancel()
            log("Timed out downloading push image")
            return
        }

        if let attachment = attachment {
            content.attachments = [attachment]
        }
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
        postWithFailover(
            apiKey: apiKey,
            jsonData: jsonData,
            hosts: resolveGatewayHosts(appGroup: appGroup),
            retryCount: 0,
            completion: completion
        )
    }

    private static func postWithFailover(
        apiKey: String,
        jsonData: Data,
        hosts: [String],
        retryCount: Int,
        completion: @escaping () -> Void
    ) {
        tryNextHost(
            apiKey: apiKey,
            jsonData: jsonData,
            hosts: hosts,
            hostIndex: 0,
            retryCount: retryCount,
            completion: completion
        )
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
            let delayMs = baseRetryDelayMs * UInt64(pow(2.0, Double(retryCount)))
                + UInt64.random(in: 0..<baseRetryDelayMs)
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(delayMs) / 1000.0) {
                postWithFailover(
                    apiKey: apiKey,
                    jsonData: jsonData,
                    hosts: hosts,
                    retryCount: retryCount + 1,
                    completion: completion
                )
            }
            return
        }

        let root = CdpGatewayUrls.normalizeBaseUrl(hosts[hostIndex])
        guard let url = URL(string: "\(root)\(CDPEndpoints.notificationMetrics)") else {
            tryNextHost(
                apiKey: apiKey,
                jsonData: jsonData,
                hosts: hosts,
                hostIndex: hostIndex + 1,
                retryCount: retryCount,
                completion: completion
            )
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
            tryNextHost(
                apiKey: apiKey,
                jsonData: jsonData,
                hosts: hosts,
                hostIndex: hostIndex + 1,
                retryCount: retryCount,
                completion: completion
            )
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

    private static func log(_ message: String) {
        os_log("[OpenCDP SDK - Push Extension] %@", message)
    }
}

/// Manages NSE lifecycle with safe expiration fallback and double-completion guard.
public final class OpenCdpNotificationExtensionSession {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var enrichedContent: UNMutableNotificationContent?
    private var didComplete = false

    public init() {}

    public func didReceive(
        _ request: UNNotificationRequest,
        appGroup: String,
        contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        let fallback = (request.content.mutableCopy() as? UNMutableNotificationContent)
            ?? UNMutableNotificationContent()
        enrichedContent = fallback

        OpenCdpPushExtensionHelper.didReceiveNotificationExtensionRequest(
            request,
            appGroup: appGroup
        ) { [weak self] modifiedContent in
            guard let self = self else { return }
            if let mutable = modifiedContent.mutableCopy() as? UNMutableNotificationContent {
                self.enrichedContent = mutable
            }
            self.finish(with: modifiedContent)
        }
    }

    public func serviceExtensionTimeWillExpire() {
        guard let content = enrichedContent else { return }
        finish(with: content)
    }

    private func finish(with content: UNNotificationContent) {
        guard !didComplete, let handler = contentHandler else { return }
        didComplete = true
        handler(content)
        contentHandler = nil
    }
}
