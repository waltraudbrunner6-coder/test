import Foundation
import PoliticalFactCheckCore

public struct OpenAIScriptProviderConfiguration: Equatable {
    public let model: String
    public let reasoningEffort: String
    public let maxOutputTokens: Int
    public let timeoutSeconds: Double
    public init(model: String = "gpt-6.1-sol", reasoningEffort: String = "medium",
                maxOutputTokens: Int = 4096, timeoutSeconds: Double = 60) {
        self.model = model; self.reasoningEffort = reasoningEffort
        self.maxOutputTokens = maxOutputTokens; self.timeoutSeconds = timeoutSeconds
    }
}

public enum OpenAIProviderError: Error, Equatable {
    case missingAPIKey, invalidRequest, authenticationFailed, permissionDenied, rateLimited, serviceUnavailable
    case networkFailure, timeout, malformedResponse, structuredOutputMissing, refused, incompleteResponse
    case invalidProviderReferences, previewChanged
}

/// A redacted rendering of the EXISTING input, not a second authoritative domain/input model.
public struct OpenAITransmissionPreview: Equatable {
    public let input: ScriptGenerationInput
    public let configuration: OpenAIScriptProviderConfiguration
    public let contentJSON: String
    public static func make(input: ScriptGenerationInput,
        configuration: OpenAIScriptProviderConfiguration = .init()) throws -> OpenAITransmissionPreview {
        guard input.evaluation.status == .approved else { throw ScriptGenerationError.evaluationNotApproved(input.evaluation.status) }
        guard !configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              ["low", "medium", "high"].contains(configuration.reasoningEffort),
              (1...8192).contains(configuration.maxOutputTokens), configuration.timeoutSeconds.isFinite,
              configuration.timeoutSeconds > 0 else { throw OpenAIProviderError.invalidRequest }
        let criterionKeys = Dictionary(uniqueKeysWithValues: input.criteria.enumerated().map { ($0.element.id, "CR-\($0.offset + 1)") })
        let actionKeys = Dictionary(uniqueKeysWithValues: input.actions.enumerated().map { ($0.element.id, "ACT-\($0.offset + 1)") })
        func exKeys(_ ids: [EntityID<SourceExcerpt>]) -> [String] {
            input.excerpts.filter { ids.contains($0.excerpt.id) }.map { $0.key }
        }
        func evKeys(_ ids: [EntityID<EvidenceLink>]) -> [String] {
            input.evidence.filter { ids.contains($0.link.id) }.map { $0.key }
        }
        let content: [String: Any] = [
            "targetDurationSeconds": input.targetDurationSeconds,
            "originalPromise": ["quote": field(input.promise.quote.content), "context": field(input.promise.context.content),
                "thesis": input.promise.thesis.value, "statementDate": dateField(input.promise.statementDate.content),
                "excerptKeys": exKeys(input.promise.quote.excerptIDs)],
            "evaluation": ["category": String(describing: input.evaluation.category), "rationale": input.evaluation.rationale.value,
                "confidence": String(describing: input.evaluation.confidence), "cutoff": date(input.evaluation.cutoff),
                "facts": input.evaluation.facts.map { $0.value }, "interpretations": input.evaluation.interpretations.map { $0.value },
                "uncertainties": input.evaluation.uncertainties.map { $0.value },
                "notVerifiableReasons": input.evaluation.notVerifiableReasons.map { String(describing: $0) }],
            "methodology": ["version": input.methodology.version.value, "title": input.methodology.title.value],
            "criteria": input.criteria.map { value -> [String: Any] in
                ["key": criterionKeys[value.id]!, "goal": value.goal.value, "targetGroup": value.targetGroup.value,
                 "deadline": date(value.deadline), "isCore": value.isCore, "materialityRule": value.materialityRule.value,
                 "baseline": field(value.baseline), "conditions": fields(value.conditions)]
            },
            "criterionEvaluations": input.criterionEvaluations.map { value -> [String: Any] in
                ["criterionKey": criterionKeys[value.criterionRevisionID]!, "category": String(describing: value.category),
                 "rationale": value.rationale.value, "confidence": String(describing: value.confidence),
                 "uncertainties": value.uncertainties.map { $0.value }, "evidenceKeys": evKeys(value.evidenceLinkIDs),
                 "counterEvidenceKeys": evKeys(value.counterEvidenceLinkIDs),
                 "notVerifiableReasons": value.notVerifiableReasons.map { String(describing: $0) }]
            },
            "sources": input.sources.map { ["key": $0.key, "title": $0.version.title?.value ?? "Titel unbekannt",
                "publisher": $0.version.publisher?.value ?? "Herausgeber unbekannt", "publicationDate": date($0.version.publicationDate)] as [String: Any] },
            "excerpts": input.excerpts.map { ["key": $0.key, "sourceKey": $0.sourceKey, "locator": $0.excerpt.locator.value,
                "text": $0.excerpt.text.value, "context": $0.excerpt.context.value, "language": $0.excerpt.language.value,
                "verificationAtSnapshot": "verified"] },
            "evidence": input.evidence.map { item -> [String: Any] in
                ["key": item.key, "criterionKey": criterionKeys[item.link.criterionRevisionID]!,
                 "excerptKeys": item.excerptKeys, "relationship": String(describing: item.link.relationship),
                 "directness": String(describing: item.link.directness), "rationale": item.link.rationale.value,
                 "temporalReference": date(item.link.temporalReference),
                 "actionKey": item.link.actionRevisionID.flatMap { actionKeys[$0] }.map { $0 as Any } ?? NSNull(),
                 "verificationAtSnapshot": "verified"]
            },
            "actions": input.actions.map { value -> [String: Any] in
                ["key": actionKeys[value.id]!, "type": String(describing: value.type), "title": value.title.value,
                 "description": field(value.description.content), "descriptionVerification": String(describing: value.description.verification),
                 "eventDate": dateField(value.eventDate.content),
                 "eventDateVerification": String(describing: value.eventDate.verification),
                 "proceduralState": value.proceduralState.value, "scope": field(value.scope.content),
                 "scopeVerification": String(describing: value.scope.verification), "excerptKeys": exKeys(value.excerptIDs)]
            }
        ]
        let bytes = try JSONSerialization.data(withJSONObject: content, options: [.sortedKeys, .prettyPrinted])
        guard let text = String(data: bytes, encoding: .utf8) else { throw OpenAIProviderError.invalidRequest }
        return OpenAITransmissionPreview(input: input, configuration: configuration, contentJSON: text)
    }
    private static func field(_ value: FieldValue<NonEmptyText>) -> [String: Any] {
        switch value {
        case .known(let text): return ["known": text.value]
        case .unknown(let reason): return ["unknown": reason.value]
        case .notApplicable(let reason): return ["notApplicable": reason.value]
        }
    }
    private static func fields(_ value: FieldValue<[NonEmptyText]>) -> [String: Any] {
        switch value {
        case .known(let texts): return ["known": texts.map { $0.value }]
        case .unknown(let reason): return ["unknown": reason.value]
        case .notApplicable(let reason): return ["notApplicable": reason.value]
        }
    }
    private static func dateField(_ value: FieldValue<DatedValue>) -> [String: Any] {
        switch value {
        case .known(let value): return date(value)
        case .unknown(let reason): return ["unknown": reason.value]
        case .notApplicable(let reason): return ["notApplicable": reason.value]
        }
    }
    private static func date(_ value: DatedValue) -> [String: Any] {
        var result: [String: Any] = ["role": String(describing: value.role), "precision": String(describing: value.precision)]
        switch value.content {
        case .known(let interval):
            let formatter = ISO8601DateFormatter()
            result["start"] = interval.start.map { formatter.string(from: $0) as Any } ?? NSNull()
            result["end"] = interval.end.map { formatter.string(from: $0) as Any } ?? NSNull()
            result["endInclusive"] = interval.endInclusive
        case .unknown(let reason): result["unknown"] = reason.value
        case .notApplicable(let reason): result["notApplicable"] = reason.value
        }
        return result
    }
}
