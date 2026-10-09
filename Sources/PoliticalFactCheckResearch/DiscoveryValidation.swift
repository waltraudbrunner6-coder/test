import Foundation
import PoliticalFactCheckCore

public enum DiscoveryDates {
    public static func value(_ string: String?, precision: String? = nil, role: DateRole) throws -> DatedValue {
        guard let string else {
            guard precision == nil else { throw DiscoveryError.invalidCandidate }
            return try .unknown(role: role, reason: NonEmptyText("Datum in der Recherche nicht zuverlässig bestimmt"))
        }
        let inferred: String
        switch string.count { case 4: inferred = "year"; case 7: inferred = "month"; case 10: inferred = "day"; default: throw DiscoveryError.invalidCandidate }
        guard precision == nil || precision == inferred else { throw DiscoveryError.invalidCandidate }
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == (inferred == "year" ? 1 : inferred == "month" ? 2 : 3),
              parts.enumerated().allSatisfy({ $0.element.count == ($0.offset == 0 ? 4 : 2) && $0.element.allSatisfy { $0.isASCII && $0.isNumber } }),
              let year = Int(parts[0]), (1900...2200).contains(year) else { throw DiscoveryError.invalidCandidate }
        let month = parts.count > 1 ? Int(parts[1])! : 1
        let day = parts.count > 2 ? Int(parts[2])! : 1
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let start = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              calendar.component(.year, from: start) == year, calendar.component(.month, from: start) == month,
              calendar.component(.day, from: start) == day,
              let end = calendar.date(byAdding: inferred == "year" ? .year : inferred == "month" ? .month : .day, value: 1, to: start) else {
            throw DiscoveryError.invalidCandidate
        }
        return try DatedValue(role: role, precision: inferred == "year" ? .year : inferred == "month" ? .month : .day,
            content: .known(PoliticalFactCheckCore.DateInterval(start: start, end: end)), timeZoneIdentifier: "UTC")
    }
}
public enum DiscoveryValidation {
    public static func validate(_ candidate: PromiseDiscoveryCandidate, sources: [ResearchWebSource],
        group: ResearchSourceGroup, request: PromiseDiscoveryRequest) throws {
        try request.validate()
        guard request.sourcePolicy.groups.contains(group) else { throw DiscoveryError.invalidPolicy }
        let texts = [candidate.candidateKey, candidate.title, candidate.exactQuote, candidate.thesis, candidate.whyCheckable, candidate.locator]
        guard texts.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.utf8.count <= 16_384 }),
              candidate.topics.count <= 12, candidate.uncertainties.count <= 20,
              (candidate.topics + candidate.uncertainties + [candidate.speakerName, candidate.partyName, candidate.sourceTitle].compactMap { $0 })
                .allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.utf8.count <= 16_384 }) else { throw DiscoveryError.invalidCandidate }
        guard candidate.statementKind == "commitment", candidate.isOriginalStatement,
              candidate.concreteTarget, candidate.observableOutcome else { throw DiscoveryError.notPrimaryCommitment }
        let url = try DiscoveryIdentity.canonicalURL(candidate.sourceURL)
        guard let parsed = URL(string: url), group.category(for: parsed) != nil else { throw DiscoveryError.outsidePolicy }
        guard let source = sources.first(where: { $0.url == url && $0.fromSearch }) else { throw DiscoveryError.unknownSource }
        guard source.domain == parsed.host?.lowercased(), source.policyVersion == request.sourcePolicy.version,
              source.category == group.category(for: parsed), source.researchTimestamp.timeIntervalSinceReferenceDate.isFinite else { throw DiscoveryError.invalidCandidate }
        if let key = candidate.sourceReferenceKey, key != source.key { throw DiscoveryError.sourceKeyMismatch }
        let date = try DiscoveryDates.value(candidate.statementDate, precision: candidate.statementDatePrecision, role: .statement)
        guard (candidate.statementDate != nil || !candidate.uncertainties.isEmpty),
              (candidate.statementDate == nil) == (candidate.statementDatePrecision == nil) else { throw DiscoveryError.invalidCandidate }
        _ = try DiscoveryDates.value(candidate.sourcePublicationDate, role: .publication)
        let due = try DiscoveryDates.value(candidate.deadline, role: .deadline)
        if let start = date.content.knownValue?.start, start > request.currentDate { throw DiscoveryError.futureStatement }
        let ageBoundary = request.currentDate.addingTimeInterval(-Double(request.minimumPromiseAge) * 86_400)
        let expired = due.content.knownValue?.end.map { $0 <= request.currentDate } ?? false
        if let end = date.content.knownValue?.end, end > ageBoundary, !expired { throw DiscoveryError.tooRecent }
    }
    /// Transparent 0...100 readiness score; all inputs remain unverified extraction claims.
    public static func score(_ candidate: PromiseDiscoveryCandidate, request: PromiseDiscoveryRequest) -> Int {
        var result = 20 // Accepted original URL in actual search sources; never a truth score.
        if candidate.concreteTarget { result += 20 }
        if candidate.observableOutcome { result += 20 }
        if candidate.speakerName != nil || candidate.partyName != nil { result += 10 }
        if candidate.statementDate != nil { result += 10 }
        if candidate.hasDeadlineOrCondition || candidate.deadline != nil { result += 10 }
        if let date = try? DiscoveryDates.value(candidate.statementDate, precision: candidate.statementDatePrecision, role: .statement),
           let end = date.content.knownValue?.end, end <= request.currentDate.addingTimeInterval(-Double(request.minimumPromiseAge) * 86_400) { result += 10 }
        else if let due = try? DiscoveryDates.value(candidate.deadline, role: .deadline), let end = due.content.knownValue?.end, end <= request.currentDate { result += 10 }
        return result
    }
}
