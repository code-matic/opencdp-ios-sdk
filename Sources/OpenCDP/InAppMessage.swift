import Foundation

public enum InAppRenderType: String, Sendable {
    case modal, banner, inline, inboxCard = "inbox_card", unknown

    static func from(_ raw: String?) -> InAppRenderType {
        guard let raw else { return .unknown }
        return InAppRenderType(rawValue: raw) ?? .unknown
    }
}

public enum InAppCtaAction: String, Sendable {
    case deepLink = "deep_link"
    case dismiss, custom, unknown
}

public enum InAppDismissReason: String, Sendable {
    case userClose = "user_close"
    case userSwipe = "user_swipe"
    case ctaDismiss = "cta_dismiss"
    case expired
    case appBackgrounded = "app_backgrounded"
    case unknown
}

public struct InAppCta: Sendable {
    public let id: String
    public let label: String
    public let action: InAppCtaAction
    public let value: String?
}

public struct InAppPersistence: Sendable {
    public let mode: String
    public let maxImpressionsTotal: Int?
    public let minIntervalSeconds: Int?
}

public struct InAppMessage: Sendable {
    public let deliveryId: String
    public let messageId: String
    public let renderType: InAppRenderType
    public let priority: Int
    public let title: String?
    public let body: String?
    public let imageUrl: String?
    public let ctas: [InAppCta]
    public let expiresAt: Date?
    public let persistence: InAppPersistence?

    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() > expiresAt
    }

    static func fromJson(_ json: [String: Any]) -> InAppMessage {
        let content = json["content"] as? [String: Any] ?? [:]
        let rawCtas = json["ctas"] as? [[String: Any]] ?? []
        let ctas = rawCtas.map { item -> InAppCta in
            InAppCta(
                id: item["id"] as? String ?? "",
                label: item["label"] as? String ?? "",
                action: InAppCtaAction(rawValue: item["action"] as? String ?? "") ?? .unknown,
                value: item["value"] as? String
            )
        }
        let persistenceJson = json["persistence"] as? [String: Any]
        let persistence = persistenceJson.map {
            InAppPersistence(
                mode: $0["mode"] as? String ?? "one_time",
                maxImpressionsTotal: $0["max_impressions_total"] as? Int,
                minIntervalSeconds: $0["min_interval_seconds"] as? Int
            )
        }
        let expiresAt = (json["expires_at"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        return InAppMessage(
            deliveryId: json["delivery_id"] as? String ?? "",
            messageId: json["message_id"] as? String ?? "",
            renderType: InAppRenderType.from(json["render_type"] as? String),
            priority: json["priority"] as? Int ?? 0,
            title: content["title"] as? String,
            body: content["body"] as? String,
            imageUrl: content["image_url"] as? String,
            ctas: ctas,
            expiresAt: expiresAt,
            persistence: persistence
        )
    }
}

public typealias InAppMessageListener = (InAppMessage) -> Void
