import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckResearch

final class ResearchReviewPlanTests: XCTestCase {
    func testProjectionCreatesNoReviewsAndReportsInitialBlockers() throws {
        let f = try DeepResearchFixture(), graph = try CaseResearchDraftMapper.adding(f.record(), to: f.graph)
        let record = try XCTUnwrap(CaseResearchDraftMapper.dossier(in: graph)), plan = try ResearchReviewPlan(graph: graph, record: record)
        XCTAssertEqual(plan.originalSource, .open); XCTAssertEqual(plan.criteria[0].state, .ready)
        XCTAssertEqual(plan.evidence[0].state, .blocked); XCTAssertEqual(plan.assessment, .blocked)
        XCTAssertTrue(plan.excerptIDs.isEmpty); XCTAssertTrue(plan.evidenceIDs.isEmpty)
        XCTAssertFalse(plan.blockingIssues.isEmpty); XCTAssertTrue(graph.reviewers.isEmpty)
        XCTAssertTrue(graph.criterionEvaluations.isEmpty); XCTAssertTrue(graph.caseEvaluations.isEmpty)
        XCTAssertEqual(try CaseResearchDraftMapper.dossier(in: graph), record)
    }
    func testMissingBindingsAreNotInferredByText() throws {
        let f = try DeepResearchFixture(), graph = try CaseResearchDraftMapper.adding(f.record(), to: f.graph)
        XCTAssertThrowsError(try ResearchReviewPlan(graph: graph, record: f.record()))
    }
}
