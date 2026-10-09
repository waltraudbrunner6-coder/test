import Foundation
import PoliticalFactCheckCore

public enum CaseResearchValidation {
    static func text(_ value: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, value.utf8.count <= 32_768 else { throw CaseResearchError.invalidResult }
    }
    static func unique(_ keys: [String]) throws { guard Set(keys).count == keys.count else { throw CaseResearchError.invalidReference }; for key in keys { try text(key) } }
    public static func validate(_ result: CaseResearchResult, request: CaseResearchRequest) throws {
        try request.validate()
        guard !result.promptVersion.isEmpty, result.startedAt == request.startedAt, result.completedAt >= result.startedAt,
              result.completedAt.timeIntervalSinceReferenceDate.isFinite, result.proposedCriteria.count <= request.maxCriteria,
              result.sources.count <= request.maxResultsPerLane * request.maximumLanes,
              result.excerpts.count <= request.maxResultsPerLane * request.maximumLanes,
              result.developments.count <= request.maxResultsPerLane * request.maximumLanes,
              result.evidenceProposals.count <= request.maxResultsPerLane * request.maximumLanes else { throw CaseResearchError.invalidResult }
        guard (result.originalSourceReview.statementDate == nil) == (result.originalSourceReview.statementDatePrecision == nil) else { throw CaseResearchError.invalidResult }
        for value in result.uncertainties + result.originalSourceReview.uncertainties { try text(value) }
        for a in result.criterionAssessmentDrafts { for value in a.facts + a.interpretations + a.uncertainties { try text(value) } }
        for value in result.overallAssessmentDraft.facts + result.overallAssessmentDraft.interpretations + result.overallAssessmentDraft.uncertainties { try text(value) }
        try text(result.originalSourceReview.context)
        _ = try DiscoveryDates.value(result.originalSourceReview.statementDate, precision: result.originalSourceReview.statementDatePrecision, role: .statement)
        try unique(result.proposedCriteria.map { $0.criterionKey }); try unique(result.sources.map { $0.claim.sourceKey })
        try unique(result.webSources.map { $0.key }); try unique(result.excerpts.map { $0.excerptKey })
        try unique(result.developments.map { $0.developmentKey }); try unique(result.evidenceProposals.map { $0.evidenceKey })
        try unique(result.criterionAssessmentDrafts.map { $0.criterionKey }); try unique(result.coverage.map { $0.criterionKey })
        if result.originalSourceReview.looksLikeCommitment {
            let originalURL = try DiscoveryIdentity.canonicalURL(request.discovery.candidate.sourceURL)
            guard result.sources.contains(where: { source in source.searchSource.url == originalURL && result.excerpts.contains(where: { $0.sourceKey == source.claim.sourceKey }) }) else { throw CaseResearchError.missingSearchSource }
        }
        let criteria = Set(result.proposedCriteria.map { $0.criterionKey })
        guard Set(result.coverage.map { $0.criterionKey }) == criteria,
              Set(result.criterionAssessmentDrafts.map { $0.criterionKey }) == criteria,
              Set(result.overallAssessmentDraft.criterionAssessmentKeys) == criteria else { throw CaseResearchError.invalidReference }
        for c in result.proposedCriteria {
            try text(c.goal); try text(c.materialityRule)
            for value in [c.targetGroup, c.baseline].compactMap({ $0 }) + (c.conditions ?? []) + c.uncertainties { try text(value) }
            _ = try DiscoveryDates.value(c.deadline, role: .deadline)
        }
        for source in result.webSources {
            let url = try DiscoveryIdentity.canonicalURL(source.url)
            guard url == source.url, let parsed = URL(string: url), source.fromSearch,
                  source.domain == parsed.host?.lowercased(), source.policyVersion == request.policy.version,
                  source.researchTimestamp.timeIntervalSinceReferenceDate.isFinite,
                  request.policy.category(for: parsed, discovery: request.discovery) != nil else { throw CaseResearchError.outsidePolicy }
        }
        for citation in result.citations {
            guard let canonical = try? DiscoveryIdentity.canonicalURL(citation.url),
                  let parsed = URL(string: canonical), request.policy.category(for: parsed, discovery: request.discovery) != nil else { throw CaseResearchError.outsidePolicy }
        }
        for s in result.sources {
            guard result.webSources.contains(s.searchSource), s.searchSource.fromSearch,
                  try DiscoveryIdentity.canonicalURL(s.claim.url) == s.searchSource.url else { throw CaseResearchError.missingSearchSource }
            guard let url = URL(string: s.searchSource.url), request.policy.category(for: url, discovery: request.discovery) == s.category else { throw CaseResearchError.outsidePolicy }
            for value in [s.claim.title, s.claim.publisher, s.claim.author, s.claim.contentType, s.claim.language].compactMap({ $0 }) { try text(value) }
            _ = try DiscoveryDates.value(s.claim.publicationDate, role: .publication); _ = try DiscoveryDates.value(s.claim.eventDate, role: .event)
        }
        let sourceKeys = Set(result.sources.map { $0.claim.sourceKey }), excerptKeys = Set(result.excerpts.map { $0.excerptKey })
        for e in result.excerpts {
            guard sourceKeys.contains(e.sourceKey) else { throw CaseResearchError.invalidReference }
            for value in [e.text, e.locator, e.context, e.language] + e.uncertainties { try text(value) }
            _ = try DiscoveryDates.value(e.eventDate, role: .event)
        }
        for d in result.developments {
            guard !d.excerptKeys.isEmpty, Set(d.excerptKeys).isSubset(of: excerptKeys) else { throw CaseResearchError.invalidReference }
            try unique(d.excerptKeys); for value in [d.title, d.description, d.proceduralState] + [d.scope].compactMap({ $0 }) + d.uncertainties { try text(value) }
            _ = try DiscoveryDates.value(d.eventDate, role: .event)
        }
        for e in result.evidenceProposals {
            guard criteria.contains(e.criterionKey), !e.excerptKeys.isEmpty, Set(e.excerptKeys).isSubset(of: excerptKeys) else { throw CaseResearchError.invalidReference }
            try unique(e.excerptKeys); try text(e.rationale)
            if let key = e.developmentKey, !result.developments.contains(where: { $0.developmentKey == key }) { throw CaseResearchError.invalidReference }
            _ = try DiscoveryDates.value(e.temporalDate, role: e.temporalRole == .event ? .event : .validity)
            if e.temporalDate == nil, e.uncertainties.isEmpty { throw CaseResearchError.invalidResult }
        }
        for coverage in result.coverage {
            guard [coverage.supportSourceCount, coverage.contradictionSourceCount, coverage.contextSourceCount].allSatisfy({ $0 >= 0 }),
                  coverage.supportSearchPerformed || coverage.supportSourceCount == 0,
                  coverage.contradictionSearchPerformed || coverage.contradictionSourceCount == 0,
                  coverage.contextSearchPerformed || coverage.contextSourceCount == 0 else { throw CaseResearchError.invalidResult }
        }
        for assessment in result.criterionAssessmentDrafts { try validate(assessment, result: result, request: request) }
        let overall = result.overallAssessmentDraft
        try text(overall.rationale)
        if let category = overall.suggestedCategory {
            guard result.originalSourceReview.looksLikeCommitment, !criteria.isEmpty,
                  result.coverage.allSatisfy({ $0.permitsRecommendation }),
                  result.criterionAssessmentDrafts.allSatisfy({ $0.suggestedCategory != nil }) else { throw CaseResearchError.unsafeAssessment }
            if category == .notVerifiable { guard !overall.notVerifiableReasons.isEmpty else { throw CaseResearchError.unsafeAssessment } }
            else {
                guard !overall.decisiveUncertainty,
                      result.criterionAssessmentDrafts.allSatisfy({ !$0.decisiveUncertainty && $0.suggestedCategory != .notVerifiable }) else { throw CaseResearchError.unsafeAssessment }
                if category == .notFulfilled || category == .contraryAction {
                    guard overall.confidence != .low, result.criterionAssessmentDrafts.contains(where: { a in a.suggestedCategory == category && result.proposedCriteria.contains(where: { $0.criterionKey == a.criterionKey && $0.isCore }) }) else { throw CaseResearchError.unsafeAssessment }
                }
                if category == .fulfilled { guard result.criterionAssessmentDrafts.allSatisfy({ $0.suggestedCategory == .fulfilled }) else { throw CaseResearchError.unsafeAssessment } }
                if category == .mostlyFulfilled {
                    let core = Set(result.proposedCriteria.filter { $0.isCore }.map { $0.criterionKey })
                    guard result.criterionAssessmentDrafts.filter({ core.contains($0.criterionKey) }).allSatisfy({ $0.suggestedCategory == .fulfilled }) else { throw CaseResearchError.unsafeAssessment }
                }
            }
        }
    }
    static func validate(_ a: ProposedCriterionAssessment, result: CaseResearchResult, request: CaseResearchRequest) throws {
        try text(a.rationale)
        let links = result.evidenceProposals.filter { $0.criterionKey == a.criterionKey }
        let keys = Set(links.map { $0.evidenceKey })
        guard Set(a.supportingEvidenceKeys + a.counterEvidenceKeys).isSubset(of: keys),
              a.supportingEvidenceKeys.allSatisfy({ key in links.contains { $0.evidenceKey == key && $0.relationship == .supports } }),
              a.counterEvidenceKeys.allSatisfy({ key in links.contains { $0.evidenceKey == key && $0.relationship == .contradicts } }) else { throw CaseResearchError.invalidReference }
        guard let category = a.suggestedCategory else { return }
        guard result.originalSourceReview.looksLikeCommitment, let coverage = result.coverage.first(where: { $0.criterionKey == a.criterionKey }), coverage.permitsRecommendation else { throw CaseResearchError.unsafeAssessment }
        if category == .notVerifiable { guard !a.notVerifiableReasons.isEmpty else { throw CaseResearchError.unsafeAssessment }; return }
        guard !a.decisiveUncertainty else { throw CaseResearchError.unsafeAssessment }
        let used = links.filter { a.supportingEvidenceKeys.contains($0.evidenceKey) || a.counterEvidenceKeys.contains($0.evidenceKey) }
        guard !used.isEmpty else { throw CaseResearchError.unsafeAssessment }
        for e in used {
            guard let interval = try DiscoveryDates.value(e.temporalDate, role: e.temporalRole == .event ? .event : .validity).content.knownValue,
                  let end = interval.end, end <= request.currentDate else { throw CaseResearchError.unsafeAssessment }
        }
        if category == .notFulfilled || category == .contraryAction {
            guard a.confidence != .low, !a.counterEvidenceKeys.isEmpty else { throw CaseResearchError.unsafeAssessment }
            let counterExcerpts = used.filter { $0.relationship == .contradicts }.flatMap { $0.excerptKeys }
            let counterSources = result.excerpts.filter { counterExcerpts.contains($0.excerptKey) }.map { $0.sourceKey }
            guard result.sources.contains(where: { counterSources.contains($0.claim.sourceKey) && $0.category.isInstitutional }) else { throw CaseResearchError.unsafeAssessment }
            if category == .contraryAction {
                guard used.contains(where: { $0.relationship == .contradicts && $0.directness == .direct && $0.developmentKey != nil }) else { throw CaseResearchError.unsafeAssessment }
            } else {
                guard a.conditionsApplicable == true, let criterion = result.proposedCriteria.first(where: { $0.criterionKey == a.criterionKey }),
                      let end = try DiscoveryDates.value(criterion.deadline, role: .deadline).content.knownValue?.end, end <= request.currentDate else { throw CaseResearchError.unsafeAssessment }
            }
        } else {
            guard !a.supportingEvidenceKeys.isEmpty else { throw CaseResearchError.unsafeAssessment }
            // Conservative gate: institutional outcome suggestions cannot rest on party claims alone.
            let supportedExcerpts = used.filter { $0.relationship == .supports }.flatMap { $0.excerptKeys }
            let sourceKeys = result.excerpts.filter { supportedExcerpts.contains($0.excerptKey) }.map { $0.sourceKey }
            guard result.sources.contains(where: { sourceKeys.contains($0.claim.sourceKey) && $0.category.isInstitutional }) else { throw CaseResearchError.unsafeAssessment }
        }
    }
}
