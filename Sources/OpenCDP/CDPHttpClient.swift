import Foundation

public enum CDPError: Error {
    case initializationError
    case invalidInput
    case networkError(String)
    case serverError(Int, String) // Add String for response body
    case decodingError
}

class CDPHttpClient {
    private let session: URLSession
    private let config: OpenCDPConfig
    
    init(config: OpenCDPConfig) {
        self.config = config
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        self.session = URLSession(configuration: configuration)
    }
    
    func post(endpoint: String, body: [String: Any]) async throws -> [String: Any]? {
        // Ensure base URL doesn't end with slash if endpoint starts with one, or vice-versa
        let characterSet = CharacterSet(charactersIn: "/").union(.whitespacesAndNewlines)
        let baseUrl = config.apiBaseUrl.trimmingCharacters(in: characterSet)
        let path = endpoint.trimmingCharacters(in: characterSet)
        
        guard let url = URL(string: "\(baseUrl)/\(path)") else {
            throw CDPError.invalidInput
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // Trim whitespace, newlines, and quotes from the API Key
        let apiKeyCleanupSet = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'"))
        let cleanApiKey = config.cdpApiKey.trimmingCharacters(in: apiKeyCleanupSet)
        
        // Use setValue to overwrite any existing header
        request.setValue(cleanApiKey, forHTTPHeaderField: "Authorization")
        
        if config.debug {
            let maskedKey = String(cleanApiKey.prefix(4)) + "..." + String(cleanApiKey.suffix(4))
            print("OpenCDP [DEBUG]: Request URL: \(url.absoluteString)")
            print("OpenCDP [DEBUG]: Sending request with API Key: \(maskedKey)")
            // Log hex bytes to detect hidden characters
            let hexString = cleanApiKey.utf8.map { String(format: "%02x", $0) }.joined(separator: " ")
            print("OpenCDP [DEBUG]: API Key Hex: \(hexString)")
            print("OpenCDP [DEBUG]: Request Headers: \(request.allHTTPHeaderFields ?? [:])")
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw CDPError.invalidInput
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let httpResponse = response as? HTTPURLResponse, self.config.debug {
                     print("OpenCDP [DEBUG]: Response Headers: \(httpResponse.allHeaderFields)")
                }
                
                if let error = error {
                    continuation.resume(throwing: CDPError.networkError(error.localizedDescription))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.resume(throwing: CDPError.networkError("Invalid response"))
                    return
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    var errorMessage = "Unknown error"
                    if let data = data, let bodyString = String(data: data, encoding: .utf8) {
                        errorMessage = bodyString
                    }
                    continuation.resume(throwing: CDPError.serverError(httpResponse.statusCode, errorMessage))
                    return
                }
                
                guard let data = data, !data.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        continuation.resume(returning: json)
                    } else {
                        continuation.resume(throwing: CDPError.decodingError)
                    }
                } catch {
                    continuation.resume(throwing: CDPError.decodingError)
                }
            }
            task.resume()
        }
    }
}
