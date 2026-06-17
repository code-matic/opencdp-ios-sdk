import Foundation

final class CDPHttpClient: @unchecked Sendable {
    let baseUrls: [String]
    private let apiKey: String
    private let debug: Bool
    private let requestTimeout: TimeInterval
    private let session: URLSession
    private let storage: CDPStorage
    private var isProcessingQueue = false
    private let queueLock = NSLock()

    init(config: OpenCDPConfig, storage: CDPStorage) {
        self.baseUrls = CdpGatewayUrls.resolveAllBaseUrls(
            primaryOverride: config.cdpEndpoint,
            fallbackOverrides: config.cdpFallbackEndpoints
        )
        self.apiKey = config.cdpApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.debug = config.debug
        self.requestTimeout = CdpGatewayUrls.clampRequestTimeout(config.cdpRequestTimeout)
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        self.session = URLSession(configuration: configuration)
        self.storage = storage
    }

    func post(endpoint: String, body: [String: Any], identifier: String? = nil) async throws {
        let success = try await postInternal(endpoint: endpoint, body: body, isRetry: false)
        if !success {
            enqueue(endpoint: endpoint, body: body, identifier: identifier)
        } else {
            await flushQueue()
        }
    }

    func get(endpoint: String, query: [String: Any]) async throws -> [String: Any]? {
        for root in baseUrls {
            guard var components = URLComponents(string: "\(root)\(endpoint)") else { continue }
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
            guard let url = components.url else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(apiKey, forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { continue }
                if (200...299).contains(http.statusCode) {
                    if data.isEmpty { return [:] }
                    return try JSONSerialization.jsonObject(with: data) as? [String: Any]
                }
                logDebug("GET \(endpoint) non-2xx on \(root) (\(http.statusCode))")
            } catch {
                logDebug("GET \(endpoint) failed on \(root): \(error.localizedDescription)")
            }
        }
        throw CDPError.networkError("All gateway hosts failed for GET \(endpoint)")
    }

    func getStreamRequest(endpoint: String, query: [String: String], headers: [String: String]) -> URLRequest? {
        for root in baseUrls {
            guard var components = URLComponents(string: "\(root)\(endpoint)") else { continue }
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            guard let url = components.url else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(apiKey, forHTTPHeaderField: "Authorization")
            headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
            return request
        }
        return nil
    }

    var sessionForStreaming: URLSession { session }

    func flushQueue() async {
        let shouldProcess: Bool = {
            queueLock.lock()
            defer { queueLock.unlock() }
            if isProcessingQueue { return false }
            isProcessingQueue = true
            return true
        }()
        guard shouldProcess else { return }

        defer {
            queueLock.lock()
            isProcessingQueue = false
            queueLock.unlock()
        }

        while let request = storage.peekQueue() {
            if request.retryCount >= 5 {
                storage.popQueue()
                continue
            }
            let delay = computeBackoffSeconds(request.retryCount)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let body = try? JSONSerialization.jsonObject(with: request.bodyData) as? [String: Any] else {
                storage.popQueue()
                continue
            }
            let success = (try? await postInternal(endpoint: request.endpoint, body: body, isRetry: true)) ?? false
            if success {
                storage.popQueue()
            } else {
                storage.popQueue()
                var updated = request
                updated.retryCount += 1
                storage.addToQueue(updated)
                break
            }
        }
    }

    private func postInternal(endpoint: String, body: [String: Any], isRetry: Bool) async throws -> Bool {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw CDPError.invalidInput
        }
        for root in baseUrls {
            guard let url = URL(string: "\(root)\(endpoint)") else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "Authorization")
            request.httpBody = jsonData
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { continue }
                if (200...299).contains(http.statusCode) {
                    logDebug("POST \(endpoint) succeeded via \(root)")
                    return true
                }
                if (400...499).contains(http.statusCode) {
                    let message = String(data: data, encoding: .utf8) ?? "Client error"
                    logDebug("POST \(endpoint) client error \(http.statusCode): \(message)")
                    return false
                }
                logDebug("POST \(endpoint) non-2xx on \(root) (\(http.statusCode))")
            } catch {
                logDebug("POST \(endpoint) failed on \(root): \(error.localizedDescription)")
            }
        }
        return false
    }

    private func enqueue(endpoint: String, body: [String: Any], identifier: String?) {
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        storage.addToQueue(CDPQueuedRequest(
            endpoint: endpoint,
            bodyData: data,
            identifier: identifier,
            retryCount: 0,
            createdAt: Date()
        ))
    }

    private func computeBackoffSeconds(_ attempt: Int) -> Double {
        let capped = min(attempt, 16)
        let exponential = pow(2.0, Double(capped))
        return Double.random(in: 0...(min(exponential, 30.0)))
    }

    private func logDebug(_ message: String) {
        if debug { print("OpenCDP [DEBUG]: \(message)") }
    }
}
