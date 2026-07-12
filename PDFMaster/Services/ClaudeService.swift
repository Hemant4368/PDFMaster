import Foundation

actor ClaudeService {
    static let shared = ClaudeService()

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-haiku-4-5-20251001"

    func summarize(text: String, apiKey: String) async throws -> String {
        let prompt = "Summarize the following PDF text in clear, concise bullet points:\n\n\(text)"
        return try await send(prompt: prompt, apiKey: apiKey)
    }

    func translate(text: String, targetLanguage: String, apiKey: String) async throws -> String {
        let prompt = "Translate the following text to \(targetLanguage). Return only the translated text:\n\n\(text)"
        return try await send(prompt: prompt, apiKey: apiKey)
    }

    private func send(prompt: String, apiKey: String) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ClaudeServiceError.missingAPIKey
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 { throw ClaudeServiceError.invalidAPIKey }
            if http.statusCode == 429 { throw ClaudeServiceError.rateLimited }
            throw ClaudeServiceError.serverError(http.statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = (json["content"] as? [[String: Any]])?.first?["text"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        return content
    }
}

enum ClaudeServiceError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:      "Enter your Claude API key in the field below."
        case .invalidAPIKey:      "Invalid API key. Check your key and try again."
        case .rateLimited:        "Rate limited. Please wait a moment and try again."
        case .serverError(let c): "Server error (\(c)). Please try again."
        }
    }
}
