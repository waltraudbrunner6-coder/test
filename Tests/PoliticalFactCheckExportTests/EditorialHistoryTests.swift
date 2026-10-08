import Foundation
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckExport

final class EditorialHistoryTests: XCTestCase {
    func testAllOldRevisionsAndHistoricalDecisionsRoundtrip() throws {
        let f = try EditorialFixture(), graph = try historyContext(f)
        let package = try EditorialPackage.create(graph: graph, evaluationID: f.base.evaluation.id, scriptID: f.script.id)
        let imported = try EditorialPackage.validate(files: package.files).domain()
        XCTAssertEqual(try PortableCaseArchiveV1(imported), try PortableCaseArchiveV1(graph))
        XCTAssertEqual(imported.promiseRevisions.count, 2); XCTAssertEqual(imported.criterionRevisions.count, 2)
        XCTAssertEqual(imported.actionRevisions.count, 2); XCTAssertEqual(imported.caseRevisions.count, 2)
        XCTAssertEqual(imported.caseEvaluations.count, 2); XCTAssertEqual(imported.scripts.count, 2)
        XCTAssertEqual(imported.auditEntries, graph.auditEntries)
        XCTAssertTrue(DomainValidator.validate(imported).isValid)
    }
    func testOldManifestIDsNeverRedirectedToNewHeads() throws {
        let f = try EditorialFixture(), graph = try historyContext(f), archive = try PortableCaseArchiveV1(graph)
        let loaded = try PortableJSON.decode(PortableCaseArchiveV1.self, from: PortableJSON.encode(archive)).domain()
        for revision in graph.caseRevisions { XCTAssertEqual(loaded.find(revision.id), revision) }
        for revision in graph.promiseRevisions { XCTAssertEqual(loaded.find(revision.id), revision) }
    }
    func testHistoricalApprovalsAndReplacementChainPreserved() throws {
        let f = try EditorialFixture(), graph = try historyContext(f)
        let loaded = try EditorialPackage.validate(files: EditorialPackage.create(graph: graph, evaluationID: f.base.evaluation.id, scriptID: f.script.id).files).domain()
        for evaluation in graph.caseEvaluations { XCTAssertEqual(loaded.find(evaluation.id), evaluation) }
        XCTAssertEqual(try CaseReviews.state(of: loaded.cases[0], in: loaded), .upToDate)
    }
    func testUnrelatedDraftHistoryIsNotPublishedAsApprovedReport() throws {
        let f = try EditorialFixture(); var a = try f.archive()
        var old = a.graph.scripts[0]; old.id.value = UUID(); old.version = 1; old.status = "draft"; old.approval = nil
        var statement = a.graph.statements[0]; statement.id.value = UUID(); statement.scriptDraftID = old.id; statement.review = nil
        old.statementIDs = [statement.id]; a.graph.scripts.append(old); a.graph.statements.append(statement)
        let package = try EditorialPackage.create(graph: a.graph.domain(), evaluationID: f.base.evaluation.id, scriptID: f.script.id)
        let report = try PortableJSON.decode(EditorialCaseReportV1.self, from: package.files["case-report.json"]!)
        XCTAssertEqual(report.script.id.value, f.script.id.rawValue)
        XCTAssertEqual(try EditorialPackage.validate(files: package.files).domain().scripts.count, 2)
        XCTAssertTrue(String(data: package.files["README.md"]!, encoding: .utf8)!.contains("nicht neu freigegeben"))
    }
    func testRecomputedHashesCannotHideStaleApproval() throws {
        let f = try EditorialFixture(); var a = try f.archive()
        var newLink = a.graph.evidenceLinks[0]; newLink.id.value = UUID(); a.graph.evidenceLinks.append(newLink)
        XCTAssertThrowsError(try EditorialPackage.create(graph: a.graph.domain(), evaluationID: f.base.evaluation.id, scriptID: f.script.id)) {
            XCTAssertEqual($0 as? EditorialPackageError, .evaluationNeedsReview)
        }
    }
    func testAffiliationAndParticipationRelationshipsRoundtrip() throws {
        let f = try EditorialFixture(); var a = try f.archive()
        let affiliation = ActorAffiliation(actorID: f.base.speaker.id, associatedActorID: f.base.party.id,
            role: text("Synthetic documented role"), validity: try .instant(EditorialFixtureBase.event, role: .validity),
            verification: .verified, excerptIDs: [f.base.excerpt.id], review: f.base.review)
        let participation = ActionParticipation(actionRevisionID: f.base.actionRevision.id, actorID: f.base.speaker.id,
            role: text("Synthetic implementing actor"), kind: .ownAction, excerptIDs: [f.base.excerpt.id], verification: .verified, review: f.base.review)
        a.graph.affiliations = [ActorAffiliationDTO(affiliation)]
        let i = try XCTUnwrap(a.graph.actors.firstIndex { $0.id.value == f.base.speaker.id.rawValue })
        a.graph.actors[i].affiliationIDs = [StoredID(affiliation.id, kind: "ActorAffiliation")]
        a.graph.participations = [ActionParticipationDTO(participation)]
        a.graph.actionRevisions[0].participationIDs = [StoredID(participation.id, kind: "ActionParticipation")]
        a.graph.caseRevisions[0].participations = [StateDTO(id: StoredID(participation.id, kind: "ActionParticipation"), state: "verified")]
        let p = try EditorialPackage.create(graph: a.domain(), evaluationID: f.base.evaluation.id, scriptID: f.script.id)
        let loaded = try EditorialPackage.validate(files: p.files).domain()
        XCTAssertEqual(loaded.affiliations, [affiliation]); XCTAssertEqual(loaded.participations, [participation])
        XCTAssertEqual(loaded.actionRevisions[0].participationIDs, [participation.id])
    }
    func testHistoricallyVerifiedSupersededSourceStillRoundtrips() throws {
        let f = try EditorialFixture(); var a = try PortableCaseArchiveV1(historyContext(f))
        var version = a.graph.sourceVersions[0]; version.id.value = UUID(); version.verification = "superseded"
        var excerpt = a.graph.excerpts[0]; excerpt.id.value = UUID(); excerpt.sourceVersionID = version.id; excerpt.state = "superseded"
        a.graph.sourceVersions.append(version); a.graph.excerpts.append(excerpt)
        let pi = try XCTUnwrap(a.graph.promiseRevisions.firstIndex { $0.id.value != f.base.promiseRevision.id.rawValue })
        a.graph.promiseRevisions[pi].quote.excerptIDs = [excerpt.id]
        let ci = try XCTUnwrap(a.graph.criterionRevisions.firstIndex { $0.id.value != f.base.criterionRevision.id.rawValue })
        var link = a.graph.evidenceLinks[0]; link.id.value = UUID(); link.criterionRevisionID = a.graph.criterionRevisions[ci].id; link.excerptIDs = [excerpt.id]; link.status = "superseded"
        a.graph.evidenceLinks.append(link)
        let si = try XCTUnwrap(a.graph.caseRevisions.firstIndex { $0.id.value != f.base.snapshot.id.rawValue })
        a.graph.caseRevisions[si].promiseRevisionID = a.graph.promiseRevisions[pi].id
        a.graph.caseRevisions[si].criteria = [StateDTO(id: a.graph.criterionRevisions[ci].id, state: "confirmed")]
        a.graph.caseRevisions[si].sourceVersions.append(StateDTO(id: version.id, state: "verified"))
        a.graph.caseRevisions[si].excerpts.append(StateDTO(id: excerpt.id, state: "verified"))
        a.graph.caseRevisions[si].evidenceLinks = [StateDTO(id: link.id, state: "verified")]
        let ei = try XCTUnwrap(a.graph.caseEvaluations.firstIndex { $0.id.value != f.base.evaluation.id.rawValue })
        let childID = a.graph.caseEvaluations[ei].criterionEvaluationIDs[0]
        let ki = try XCTUnwrap(a.graph.criterionEvaluations.firstIndex { $0.id == childID })
        a.graph.criterionEvaluations[ki].criterionRevisionID = a.graph.criterionRevisions[ci].id
        a.graph.criterionEvaluations[ki].evidenceLinkIDs = [link.id]
        // The historical script follows its historical evaluation and verified-at-snapshot evidence.
        let oldScript = try XCTUnwrap(a.graph.scripts.first { $0.id.value != f.script.id.rawValue })
        let oldStatementID = oldScript.statementIDs[0]
        let ti = try XCTUnwrap(a.graph.statements.firstIndex { $0.id == oldStatementID })
        a.graph.statements[ti].excerptIDs = [excerpt.id]; a.graph.statements[ti].evidenceLinkIDs = [link.id]
        let context = try a.domain()
        let package = try EditorialPackage.create(graph: context, evaluationID: f.base.evaluation.id, scriptID: f.script.id)
        let loaded = try EditorialPackage.validate(files: package.files).domain()
        XCTAssertEqual(loaded.find(try version.id.domain(SourceVersion.self, kind: "SourceVersion"))?.verification, .superseded)
        XCTAssertEqual(try PortableCaseArchiveV1(loaded), try PortableCaseArchiveV1(context))
    }
    func testOrphanHistoricalAuditReferenceRejected() throws {
        let f = try EditorialFixture(); var a = try f.archive(); a.graph.auditEntries[0].target.id = UUID()
        XCTAssertThrowsError(try a.domain())
    }
    func testBrokenHistoricalPromiseRejectedEvenIfNotCurrent() throws {
        let f = try EditorialFixture(); var a = try PortableCaseArchiveV1(historyContext(f))
        let index = try XCTUnwrap(a.graph.promiseRevisions.firstIndex { $0.id.value != f.base.promiseRevision.id.rawValue })
        a.graph.promiseRevisions[index].promiseID.value = UUID()
        XCTAssertThrowsError(try a.domain())
    }
}
func historyContext(_ f: EditorialFixture) throws -> DomainContext {
    var a = try f.archive()
    var promise = a.graph.promiseRevisions[0]; promise.id.value = UUID()
    var criterion = a.graph.criterionRevisions[0]; criterion.id.value = UUID(); criterion.promiseRevisionID = promise.id
    var action = a.graph.actionRevisions[0]; action.id.value = UUID()
    a.graph.promiseRevisions[0].metadata.number = 2; a.graph.criterionRevisions[0].metadata.number = 2; a.graph.actionRevisions[0].metadata.number = 2
    a.graph.promiseRevisions.append(promise); a.graph.criterionRevisions.append(criterion); a.graph.actionRevisions.append(action)
    var snapshot = a.graph.caseRevisions[0]; snapshot.id.value = UUID()
    a.graph.caseRevisions[0].metadata.number = 2; a.graph.caseRevisions.append(snapshot)
    var oldEvaluation = a.graph.caseEvaluations[0]; oldEvaluation.id.value = UUID(); oldEvaluation.caseRevisionID = snapshot.id; oldEvaluation.status = "superseded"
    var child = a.graph.criterionEvaluations[0]; child.id.value = UUID(); child.caseEvaluationID = oldEvaluation.id
    oldEvaluation.criterionEvaluationIDs = [child.id]
    a.graph.caseEvaluations[0].replacesEvaluationID = oldEvaluation.id
    a.graph.caseEvaluations.append(oldEvaluation); a.graph.criterionEvaluations.append(child)
    var script = a.graph.scripts[0]; script.id.value = UUID(); script.caseEvaluationID = oldEvaluation.id; script.version = 1; script.status = "superseded"
    var statement = a.graph.statements[0]; statement.id.value = UUID(); statement.scriptDraftID = script.id
    script.statementIDs = [statement.id]
    a.graph.scripts.append(script); a.graph.statements.append(statement)
    return try a.domain()
}
