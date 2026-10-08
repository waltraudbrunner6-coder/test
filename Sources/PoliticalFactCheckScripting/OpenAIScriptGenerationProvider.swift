import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import PoliticalFactCheckCore

public struct OpenAIScriptGenerationProvider: ScriptGenerationProvider {
    public static let promptVersion = "openai-script-prompt-v1"
    public let configuration: OpenAIScriptProviderConfiguration
    private let session: URLSession
    private let environment: (String) -> String?
    private let safetyIdentifier: String
    public var identifier: NonEmptyText { try! NonEmptyText("openai/\(configuration.model)/\(Self.promptVersion)") }
    public init(configuration: OpenAIScriptProviderConfiguration = .init(),
                session: URLSession = URLSession(configuration: .ephemeral),
                safetyIdentifier: String,
                environment: @escaping (String) -> String? = { ProcessInfo.processInfo.environment[$0] }) {
        self.configuration = configuration; self.session = session
        self.safetyIdentifier = safetyIdentifier; self.environment = environment
    }
    public static func instructions() throws -> String {
        guard let url = Bundle.module.url(forResource: promptVersion, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { throw OpenAIProviderError.invalidRequest }
        return text
    }
    public func generateScript(input: ScriptGenerationInput) async throws -> ScriptGenerationOutput {
        let preview = try OpenAITransmissionPreview.make(input: input, configuration: configuration)
        let request = try makeRequest(preview: preview)
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch is CancellationError { throw CancellationError() }
        catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw error.code == .timedOut ? OpenAIProviderError.timeout : OpenAIProviderError.networkFailure
        }
        catch { throw OpenAIProviderError.networkFailure }
        guard let http = response as? HTTPURLResponse else { throw OpenAIProviderError.malformedResponse }
        switch http.statusCode {
        case 200...299: break
        case 401: throw OpenAIProviderError.authenticationFailed
        case 403: throw OpenAIProviderError.permissionDenied
        case 408: throw OpenAIProviderError.timeout
        case 429: throw OpenAIProviderError.rateLimited
        case 500...599: throw OpenAIProviderError.serviceUnavailable
        default: throw OpenAIProviderError.invalidRequest
        }
        return try decode(data, input: input)
    }
    /// Only transient request memory contains the credential. No request/body/header logging.
    func makeRequest(preview: OpenAITransmissionPreview) throws -> URLRequest {
        guard preview.configuration == configuration,
              UUID(uuidString: safetyIdentifier) != nil else { throw OpenAIProviderError.invalidRequest }
        guard let key = environment("OPENAI_API_KEY"), !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw OpenAIProviderError.missingAPIKey }
        guard !key.contains("\r"), !key.contains("\n") else { throw OpenAIProviderError.invalidRequest }
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!,
            cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: configuration.timeoutSeconds)
        request.httpMethod = "POST"
        request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["model": configuration.model, "reasoning": ["effort": configuration.reasoningEffort],
            "store": false, "stream": false, "safety_identifier": safetyIdentifier,
            "max_output_tokens": configuration.maxOutputTokens, "instructions": try Self.instructions(),
            "input": [["role": "user", "content": [["type": "input_text", "text": preview.contentJSON]]]],
            "text": ["format": ["type": "json_schema", "name": "script_draft_v1", "strict": true, "schema": Self.outputSchema]]]
        do { request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]) }
        catch { throw OpenAIProviderError.invalidRequest }
        return request
    }
    static var outputSchema: [String: Any] {
        let fields: [String: Any] = ["position": ["type": "integer", "minimum": 0], "text": ["type": "string"],
            "kind": ["type": "string", "enum": ["fact", "interpretation", "question", "qualification"]],
            "referencedExcerptKeys": ["type": "array", "items": ["type": "string"]],
            "referencedEvidenceKeys": ["type": "array", "items": ["type": "string"]],
            "uncertainty": ["type": ["string", "null"]]]
        return ["type": "object", "additionalProperties": false, "required": ["statements"],
            "properties": ["statements": ["type": "array", "minItems": 1, "maxItems": 12,
                "items": ["type": "object", "additionalProperties": false, "required": fields.keys.sorted(), "properties": fields]]]]
    }
    private func decode(_ data: Data, input: ScriptGenerationInput) throws -> ScriptGenerationOutput {
        guard data.count <= 1_048_576, let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw OpenAIProviderError.malformedResponse }
        if envelope["status"] as? String == "incomplete" { throw OpenAIProviderError.incompleteResponse }
        if envelope["status"] as? String == "failed" {
            let code = (envelope["error"] as? [String: Any])?["code"] as? String
            switch code {
            case "server_error": throw OpenAIProviderError.serviceUnavailable
            case "rate_limit_exceeded": throw OpenAIProviderError.rateLimited
            case "invalid_prompt": throw OpenAIProviderError.invalidRequest
            case "content_filter": throw OpenAIProviderError.refused
            default: throw OpenAIProviderError.malformedResponse
            }
        }
        guard envelope["status"] as? String == "completed", envelope["error"] == nil || envelope["error"] is NSNull else { throw OpenAIProviderError.malformedResponse }
        guard let items = envelope["output"] as? [[String: Any]] else { throw OpenAIProviderError.structuredOutputMissing }
        var texts: [String] = []
        for item in items {
            guard item["type"] as? String == "message" else {
                if item["type"] as? String == "reasoning" { continue }
                throw OpenAIProviderError.structuredOutputMissing
            }
            guard item["role"] as? String == "assistant", item["status"] as? String == "completed",
                  let content = item["content"] as? [[String: Any]] else { throw OpenAIProviderError.malformedResponse }
            for part in content {
                if part["type"] as? String == "refusal" { throw OpenAIProviderError.refused }
                guard part["type"] as? String == "output_text", let text = part["text"] as? String else { throw OpenAIProviderError.structuredOutputMissing }
                texts.append(text)
            }
        }
        guard texts.count == 1, let bytes = texts.first?.data(using: .utf8) else { throw OpenAIProviderError.structuredOutputMissing }
        guard let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any], Set(object.keys) == ["statements"],
              let statements = object["statements"] as? [[String: Any]], !statements.isEmpty, statements.count <= 12,
              statements.allSatisfy({ Set($0.keys) == ["position", "text", "kind", "referencedExcerptKeys", "referencedEvidenceKeys", "uncertainty"] }) else { throw OpenAIProviderError.malformedResponse }
        let decoded: OutputDTO
        do { decoded = try JSONDecoder().decode(OutputDTO.self, from: bytes) }
        catch { throw OpenAIProviderError.malformedResponse }
        let output = ScriptGenerationOutput(statements: try decoded.statements.map { value in
            let kind: ScriptStatementKind
            switch value.kind {
            case "fact": kind = .fact
            case "interpretation": kind = .interpretation
            case "question": kind = .question
            case "qualification": kind = .qualification
            default: throw OpenAIProviderError.malformedResponse
            }
            return GeneratedScriptStatement(position: value.position, text: value.text, kind: kind,
                referencedExcerptKeys: value.referencedExcerptKeys, referencedEvidenceKeys: value.referencedEvidenceKeys, uncertainty: value.uncertainty)
        })
        do { try ScriptOutputValidator.validate(output, input: input) }
        catch { throw OpenAIProviderError.invalidProviderReferences }
        return output
    }
}
private struct OutputDTO: Decodable { let statements: [StatementDTO] }
private struct StatementDTO: Decodable {
    let position: Int; let text: String; let kind: String
    let referencedExcerptKeys: [String]; let referencedEvidenceKeys: [String]; let uncertainty: String?
}
