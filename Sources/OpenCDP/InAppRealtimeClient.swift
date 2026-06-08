import Foundation

final class InAppRealtimeClient {
    private let httpClient: CDPHttpClient
    private let personId: String
    private let debug: Bool
    private let maxBackoff: TimeInterval
    private let staleTimeout: TimeInterval
    private var task: Task<Void, Never>?
    var onSyncRequested: (() -> Void)?

    init(httpClient: CDPHttpClient, personId: String, debug: Bool, maxBackoff: TimeInterval, staleTimeout: TimeInterval) {
        self.httpClient = httpClient
        self.personId = personId
        self.debug = debug
        self.maxBackoff = maxBackoff
        self.staleTimeout = staleTimeout
    }

    func start() {
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            var retryAttempt = 0
            while !Task.isCancelled {
                await self.openStream()
                let delay = min(pow(2.0, Double(retryAttempt)), self.maxBackoff)
                try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 0...delay) * 1_000_000_000))
                retryAttempt += 1
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func openStream() async {
        guard let request = httpClient.getStreamRequest(
            endpoint: CDPEndpoints.inAppStream,
            query: ["person_id": personId],
            headers: [
                "Accept": "text/event-stream",
                "Cache-Control": "no-cache",
            ]
        ) else { return }

        do {
            let (data, response) = try await httpClient.sessionForStreaming.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
            guard let text = String(data: data, encoding: .utf8) else { return }
            let parser = SseParser()
            for event in parser.addChunk(text) {
                if event.event == "sync" || event.event == nil {
                    onSyncRequested?()
                }
            }
        } catch {
            if debug { print("OpenCDP [DEBUG]: SSE error: \(error.localizedDescription)") }
        }
    }
}
