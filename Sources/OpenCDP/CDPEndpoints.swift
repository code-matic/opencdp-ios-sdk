import Foundation

enum CDPEndpoints {
    static let baseURL = "https://api.opencdp.io/gateway/data-gateway"
    static let backupBaseURLCom = "https://api.opencdp.com/gateway/data-gateway"
    static let backupBaseURLXyz = "https://api.opencdp.xyz/gateway/data-gateway"

    static let version = "/v1"
    static let identify = "\(version)/persons/identify"
    static let track = "\(version)/persons/track"
    static let registerDevice = "\(version)/persons/registerDevice"
    static let notificationMetrics = "\(version)/message/delivery/push"
    static let inAppSync = "\(version)/in-app/messages/sync"
    static let inAppStream = "\(version)/in-app/messages/stream"

    static func inAppImpression(_ deliveryId: String) -> String {
        "\(version)/in-app/messages/\(deliveryId)/impression"
    }

    static func inAppClick(_ deliveryId: String) -> String {
        "\(version)/in-app/messages/\(deliveryId)/click"
    }

    static func inAppDismiss(_ deliveryId: String) -> String {
        "\(version)/in-app/messages/\(deliveryId)/dismiss"
    }
}

enum CdpGatewayUrls {
    static let defaultFallbackBaseUrls = [
        CDPEndpoints.backupBaseURLCom,
        CDPEndpoints.backupBaseURLXyz,
    ]

    static func clampRequestTimeout(_ value: TimeInterval) -> TimeInterval {
        min(max(value, 5), 120)
    }

    static func normalizeBaseUrl(_ url: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    static func resolveAllBaseUrls(primaryOverride: String?, fallbackOverrides: [String]?) -> [String] {
        let primary = normalizeBaseUrl(
            (primaryOverride?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? primaryOverride! : CDPEndpoints.baseURL
        )
        var seen = Set<String>()
        var ordered: [String] = []
        func add(_ url: String) {
            let normalized = normalizeBaseUrl(url)
            if !normalized.isEmpty, seen.insert(normalized).inserted {
                ordered.append(normalized)
            }
        }
        add(primary)
        (fallbackOverrides ?? defaultFallbackBaseUrls).forEach(add)
        return ordered
    }
}

enum OpenCdpStorageKeys {
    static let apiKey = "opencdpsdk_api_key"
    static let userId = "opencdpsdk_user_id"
    static let baseUrl = "opencdpsdk_base_url"
    static let baseUrls = "opencdpsdk_base_urls"
    static let deviceId = "opencdpsdk_device_id"
}
