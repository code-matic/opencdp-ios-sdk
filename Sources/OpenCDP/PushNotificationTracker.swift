import Foundation

public struct CDPPushAction: Sendable {
    public let actionId: String
    public let label: String
    public let link: String?
    public let icon: String?
}

public enum OpenCDPPushPayload {
    public static func parseCustomData(_ data: [String: String]) -> [String: Any]? {
        guard let raw = data["custom_data"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              raw.hasPrefix("{"),
              let jsonData = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }
        return object
    }

    public static func parseActions(_ data: [String: String], maxActions: Int = 3) -> [CDPPushAction] {
        guard let raw = data["actions"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              raw.hasPrefix("["),
              let jsonData = raw.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            return []
        }
        var out: [CDPPushAction] = []
        for item in array {
            if out.count >= maxActions { break }
            let actionId = (item["action_id"] as? String ?? item["actionId"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let label = (item["label"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if actionId.isEmpty || label.isEmpty { continue }
            let link = (item["link"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let icon = (item["icon"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            out.append(CDPPushAction(
                actionId: actionId,
                label: label,
                link: link?.isEmpty == true ? nil : link,
                icon: icon?.isEmpty == true ? nil : icon
            ))
        }
        return out
    }

    public static func resolveActionId(_ data: [String: String]) -> String? {
        for key in ["action_clicked", "action_id", "actionId"] {
            if let value = data[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    public static func normalizeImageUrl(_ url: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        return "https://\(trimmed)"
    }

    public static func parseImageUrl(_ data: [String: String]) -> String? {
        guard let raw = data["image_url"] else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : normalizeImageUrl(trimmed)
    }
}

enum PushNotificationTracker {
    static func sendMetric(
        apiKey: String,
        baseUrls: [String],
        status: String,
        data: [String: String],
        personId: String?,
        actionId: String? = nil
    ) async -> Bool {
        let deliveryMessageId = data["delivery_message_id"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !deliveryMessageId.isEmpty else { return false }
        let trimmedPersonId = data["person_id"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPersonId = (trimmedPersonId?.isEmpty == false ? trimmedPersonId : nil) ?? personId
        guard let resolvedPersonId else { return false }

        var body: [String: Any] = [
            "message_id": deliveryMessageId,
            "person_id": resolvedPersonId,
            "send_context": data["delivery_send_context"] ?? "transactional",
            "send_context_id": data["delivery_send_context_id"] ?? "",
            "status": status,
            "ts": ISO8601DateFormatter().string(from: Date()),
        ]
        if status == "clicked", let actionId, !actionId.isEmpty {
            body["props"] = ["action_id": actionId]
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return false }
        let hosts = baseUrls.isEmpty ? CdpGatewayUrls.resolveAllBaseUrls(primaryOverride: nil, fallbackOverrides: nil) : baseUrls
        var retryCount = 0
        while retryCount <= 3 {
            for root in hosts {
                let urlString = "\(CdpGatewayUrls.normalizeBaseUrl(root))\(CDPEndpoints.notificationMetrics)"
                guard let url = URL(string: urlString) else { continue }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 8
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(apiKey, forHTTPHeaderField: "Authorization")
                request.httpBody = jsonData
                do {
                    let (_, response) = try await URLSession.shared.data(for: request)
                    if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                        return true
                    }
                } catch { continue }
            }
            retryCount += 1
            try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount - 1)) * 1_000_000_000))
        }
        return false
    }
}
