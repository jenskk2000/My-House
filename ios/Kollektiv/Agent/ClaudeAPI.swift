import Foundation

enum Secrets {
    /// Read from Info.plist, which is populated from Secrets.xcconfig at build time.
    static var anthropicAPIKey: String? {
        let v = (Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (v?.isEmpty == false) ? v : nil
    }
}

struct ToolDefinition: Encodable, Equatable {
    let name: String
    let description: String
    let input_schema: JSONValue
}

struct ClaudeMessage: Codable, Equatable {
    let role: String            // "user" | "assistant"
    let content: JSONValue      // always an array of content blocks; kept raw so thinking blocks round-trip

    static func user(text: String) -> ClaudeMessage {
        .init(role: "user", content: .array([.object(["type": .string("text"), "text": .string(text)])]))
    }
    static func toolResults(_ results: [(toolUseID: String, content: String, isError: Bool)]) -> ClaudeMessage {
        .init(role: "user", content: .array(results.map {
            .object(["type": .string("tool_result"), "tool_use_id": .string($0.toolUseID),
                     "content": .string($0.content), "is_error": .bool($0.isError)])
        }))
    }
}

struct OutputConfig: Encodable, Equatable { let effort: String }

struct ClaudeRequest: Encodable, Equatable {
    var model: String = "claude-sonnet-5"
    var max_tokens: Int = 16000
    var system: String
    var tools: [ToolDefinition]
    var messages: [ClaudeMessage]
    var output_config: OutputConfig = .init(effort: "medium")
}

struct ClaudeResponse: Decodable, Equatable {
    let content: JSONValue       // array of blocks
    let stop_reason: String?

    struct ToolUse: Equatable { let id: String; let name: String; let input: JSONValue }

    var toolUses: [ToolUse] {
        (content.arrayValue ?? []).compactMap { block in
            guard block["type"]?.stringValue == "tool_use",
                  let id = block["id"]?.stringValue, let name = block["name"]?.stringValue else { return nil }
            return ToolUse(id: id, name: name, input: block["input"] ?? .object([:]))
        }
    }
    var text: String {
        (content.arrayValue ?? []).compactMap { $0["type"]?.stringValue == "text" ? $0["text"]?.stringValue : nil }
            .joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    /// The assistant turn to echo back verbatim (includes thinking blocks and signatures).
    var assistantMessage: ClaudeMessage { .init(role: "assistant", content: content) }
}

struct ClaudeAPIError: Error, LocalizedError, Decodable {
    struct Body: Decodable { let type: String; let message: String }
    let error: Body
    var errorDescription: String? { "\(error.type): \(error.message)" }
}

protocol AgentClient {
    func complete(_ request: ClaudeRequest) async throws -> ClaudeResponse
}

struct ClaudeAgentClient: AgentClient {
    let apiKey: String
    var session: URLSession = .shared

    func complete(_ request: ClaudeRequest) async throws -> ClaudeResponse {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            if let apiErr = try? JSONDecoder().decode(ClaudeAPIError.self, from: data) { throw apiErr }
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "HTTP \(status)"])
        }
        return try JSONDecoder().decode(ClaudeResponse.self, from: data)
    }
}
