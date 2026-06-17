import Foundation

struct ParsedSseEvent {
    let event: String?
    let data: String
}

final class SseParser {
    private var lineBuffer = ""
    private var dataLines: [String] = []
    private var eventName: String?

    func addChunk(_ chunk: String) -> [ParsedSseEvent] {
        guard !chunk.isEmpty else { return [] }
        lineBuffer += chunk
        var events: [ParsedSseEvent] = []
        while let line = extractNextLine() {
            if let event = processLine(line) {
                events.append(event)
            }
        }
        return events
    }

    private func extractNextLine() -> String? {
        guard let newlineIndex = lineBuffer.firstIndex(of: "\n") else { return nil }
        let line = String(lineBuffer[..<newlineIndex]).trimmingCharacters(in: .newlines)
        lineBuffer = String(lineBuffer[lineBuffer.index(after: newlineIndex)...])
        return line
    }

    private func processLine(_ line: String) -> ParsedSseEvent? {
        if line.isEmpty {
            guard !dataLines.isEmpty || eventName != nil else { return nil }
            let event = ParsedSseEvent(event: eventName, data: dataLines.joined(separator: "\n"))
            dataLines.removeAll()
            eventName = nil
            return event
        }
        if line.hasPrefix(":") { return nil }
        let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
        guard let field = parts.first else { return nil }
        let value = parts.count > 1 ? String(parts[1].drop(while: { $0 == " " })) : ""
        switch field {
        case "event": eventName = value
        case "data": dataLines.append(value)
        default: break
        }
        return nil
    }
}
