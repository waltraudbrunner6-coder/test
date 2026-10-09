import Foundation
import PoliticalFactCheckCore
import PoliticalFactCheckResearch

extension LocalCaseStore {
    public func researchDossier(caseID: EntityID<Case>) throws -> DeepResearchRecordV1? {
        guard let graph = try loadCase(id: caseID) else { throw PersistenceError.missingEntity(kind: "Case", id: caseID.rawValue) }
        return try CaseResearchDraftMapper.dossier(in: graph)
    }
    public func caseResearchRequest(caseID: EntityID<Case>, policy: EvidenceSourcePolicy, currentDate: Date = Date()) throws -> CaseResearchRequest {
        guard let graph = try loadCase(id: caseID) else { throw PersistenceError.missingEntity(kind: "Case", id: caseID.rawValue) }
        if try CaseResearchDraftMapper.dossier(in: graph) != nil { throw CaseResearchError.alreadyResearched }
        return try CaseResearchRequest.make(in: graph, policy: policy, currentDate: currentDate)
    }
    public func saveCaseResearch(_ record: DeepResearchRecordV1) throws {
        try transaction("saveCaseResearch") { context in
            guard let graph = try readCase(record.caseID, in: context) else { throw PersistenceError.missingEntity(kind: "Case", id: record.caseID) }
            let updated = try CaseResearchDraftMapper.adding(record, to: graph)
            try writeCase(updated, in: context)
        }
    }
}
