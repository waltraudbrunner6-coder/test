import Foundation

/// Typed wire DTO; dictionaries are used only to describe the API's JSON Schema.
struct ResearchLaneOutput: Codable {
    let originalSourceReview: OriginalSourceReview?
    let proposedCriteria: [ProposedCriterion]
    let sources: [ResearchSourceClaim]
    let excerpts: [ProposedExcerpt]
    let developments: [ProposedDevelopment]
    let evidenceProposals: [EvidenceProposal]
    let criterionAssessments: [ProposedCriterionAssessment]
    let overallAssessment: ProposedCaseAssessment?
    let uncertainties: [String]
}
enum CaseResearchSchema {
    static let string: [String: Any] = ["type": "string"]
    static let nullableString: [String: Any] = ["type": ["string", "null"]]
    static let boolean: [String: Any] = ["type": "boolean"]
    static var strings: [String: Any] { array(string) }
    static func array(_ value: [String: Any]) -> [String: Any] { ["type": "array", "items": value] }
    static func enumeration(_ values: [String], nullable: Bool = false) -> [String: Any] {
        ["type": nullable ? ["string", "null"] as Any : "string" as Any, "enum": nullable ? values.map { $0 as Any } + [NSNull()] : values.map { $0 as Any }]
    }
    static func object(_ fields: [String: Any], nullable: Bool = false) -> [String: Any] {
        ["type": nullable ? ["object", "null"] as Any : "object" as Any, "additionalProperties": false, "required": fields.keys.sorted(), "properties": fields]
    }
    static let categories = ["fulfilled", "mostlyFulfilled", "partiallyFulfilled", "notFulfilled", "contraryAction", "notVerifiable"]
    static let reasons = ["unclearPromise", "openDeadline", "conditionNotMet", "missingEvidence", "unclearAttribution", "conflictingSources", "researchBlocked"]
    static var assessmentFields: [String: Any] {
        ["suggestedCategory": enumeration(categories, nullable: true), "confidence": enumeration(["high", "medium", "low"]), "rationale": string,
         "facts": strings, "interpretations": strings, "uncertainties": strings, "notVerifiableReasons": array(enumeration(reasons)), "decisiveUncertainty": boolean]
    }
    static var schema: [String: Any] {
        var criterionAssessment = assessmentFields
        criterionAssessment["criterionKey"] = string; criterionAssessment["supportingEvidenceKeys"] = strings; criterionAssessment["counterEvidenceKeys"] = strings
        criterionAssessment["conditionsApplicable"] = ["type": ["boolean", "null"]]
        var overall = assessmentFields; overall["criterionAssessmentKeys"] = strings
        return object([
            "originalSourceReview": object(["context": string, "looksLikeCommitment": boolean, "statementDate": nullableString, "statementDatePrecision": nullableString, "uncertainties": strings], nullable: true),
            "proposedCriteria": array(object(["criterionKey": string, "goal": string, "targetGroup": nullableString, "baseline": nullableString, "deadline": nullableString,
                "conditions": ["type": ["array", "null"], "items": string], "isCore": boolean, "materialityRule": string, "uncertainties": strings])),
            "sources": array(object(["sourceKey": string, "url": string, "title": nullableString, "publisher": nullableString, "author": nullableString,
                "publicationDate": nullableString, "eventDate": nullableString, "contentType": nullableString, "language": nullableString])),
            "excerpts": array(object(["excerptKey": string, "sourceKey": string, "text": string, "locator": string, "context": string, "language": string, "eventDate": nullableString, "uncertainties": strings])),
            "developments": array(object(["developmentKey": string, "title": string, "type": enumeration(["vote", "initiative", "resolution", "implementation", "development", "other"]),
                "description": string, "eventDate": nullableString, "proceduralState": string, "scope": nullableString, "excerptKeys": strings, "uncertainties": strings])),
            "evidenceProposals": array(object(["evidenceKey": string, "criterionKey": string, "excerptKeys": strings, "developmentKey": nullableString,
                "relationship": enumeration(["supports", "contradicts", "contextualizes"]), "directness": enumeration(["direct", "indirect"]), "rationale": string,
                "temporalRole": enumeration(["event", "validity"]), "temporalDate": nullableString, "uncertainties": strings])),
            "criterionAssessments": array(object(criterionAssessment)), "overallAssessment": object(overall, nullable: true), "uncertainties": strings])
    }
    static func validateJSON(_ value: Any, schema: [String: Any]) throws {
        if value is NSNull {
            guard (schema["type"] as? [String])?.contains("null") == true else { throw DiscoveryError.invalidStructuredOutput }; return
        }
        if let fields = schema["properties"] as? [String: Any] {
            guard let object = value as? [String: Any], Set(object.keys) == Set(fields.keys) else { throw DiscoveryError.invalidStructuredOutput }
            for (key, field) in fields { try validateJSON(object[key]!, schema: field as! [String: Any]) }
        } else if let items = schema["items"] as? [String: Any] {
            guard let array = value as? [Any] else { throw DiscoveryError.invalidStructuredOutput }
            for item in array { try validateJSON(item, schema: items) }
        } else {
            let type = schema["type"] as? String ?? (schema["type"] as? [String])?.first
            if type == "string", !(value is String) { throw DiscoveryError.invalidStructuredOutput }
            if type == "boolean" {
                guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
                      (try? JSONDecoder().decode(Bool.self, from: data)) != nil else { throw DiscoveryError.invalidStructuredOutput }
            }
        }
    }
}
