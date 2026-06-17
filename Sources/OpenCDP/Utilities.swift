import Foundation
import CryptoKit

enum HashGenerator {
    static func generateMd5Hash(_ input: String) -> String {
        let data = Data(input.lowercased().utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

enum IdentifierValidator {
    private static let emailRegex = try? NSRegularExpression(
        pattern: "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$",
        options: [.caseInsensitive]
    )

    static func isValidIdentifier(_ identifier: String) -> Bool {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        if let emailRegex, emailRegex.firstMatch(in: trimmed, range: range) != nil {
            return false
        }
        return true
    }

    static func isValidEventName(_ eventName: String) -> Bool {
        !eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func isValidPushToken(_ token: String?) -> Bool {
        guard let token else { return false }
        return !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
