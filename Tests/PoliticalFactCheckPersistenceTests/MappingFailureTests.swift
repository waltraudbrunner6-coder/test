import Foundation
import SwiftData
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckPersistence

final class MappingFailureTests: XCTestCase {
    func testDuplicateDomainIDIsRejectedBeforeSave() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            var dto = CaseGraphDTO(f.context()); dto.actors.append(dto.actors[0])
            let store = try LocalCaseStore.inMemory()
            XCTAssertThrowsError(try store.saveCase(dto.domain()))
            XCTAssertTrue(try store.listCases().isEmpty)
        }
    }

    func testMissingSourceVersionInStoreIsExplicitError() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(f.context())
            let context = store.freshContext()
            let row = try XCTUnwrap(context.fetch(FetchDescriptor<PersistenceSchemaV1.SourceVersionRecord>()).first)
            context.delete(row); try context.save()
            XCTAssertThrowsError(try store.loadCase(id: f.politicalCase.id)) { error in
                XCTAssertEqual(error as? PersistenceError, .missingEntity(kind: "SourceVersion", id: f.sourceVersion.id.rawValue))
            }
        }
    }

    func testDuplicateStoredIDIsNotSilentlyUpserted() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(f.context())
            let context = store.freshContext()
            context.insert(PersistenceSchemaV1.SourceVersionRecord(id: f.sourceVersion.id.rawValue,
                payload: try PayloadCodec.encode(SourceVersionDTO(f.sourceVersion))))
            try context.save()
            XCTAssertThrowsError(try store.loadCase(id: f.politicalCase.id)) { error in
                XCTAssertEqual(error as? PersistenceError, .duplicateID(kind: "SourceVersion", id: f.sourceVersion.id.rawValue))
            }
        }
    }

    func testWrongEntityIDTypeIsRejected() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(f.context())
            let context = store.freshContext()
            let row = try XCTUnwrap(context.fetch(FetchDescriptor<PersistenceSchemaV1.SourceExcerptRecord>()).first)
            var dto = try PayloadCodec.decode(SourceExcerptDTO.self, from: row.payload)
            dto.sourceVersionID.kind = "Actor"
            row.payload = try PayloadCodec.encode(dto); try context.save()
            XCTAssertThrowsError(try store.loadCase(id: f.politicalCase.id)) { error in
                XCTAssertEqual(error as? PersistenceError,
                    .wrongIDType(expected: "SourceVersion", actual: "Actor", id: f.sourceVersion.id.rawValue))
            }
        }
    }

    func testBrokenExcerptRelationshipIsNotRepaired() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(f.context())
            let context = store.freshContext()
            let row = try XCTUnwrap(context.fetch(FetchDescriptor<PersistenceSchemaV1.SourceExcerptRecord>()).first)
            var dto = try PayloadCodec.decode(SourceExcerptDTO.self, from: row.payload)
            dto.sourceVersionID = StoredID(EntityID<SourceVersion>(), kind: "SourceVersion")
            row.payload = try PayloadCodec.encode(dto); try context.save()
            XCTAssertThrowsError(try store.loadCase(id: f.politicalCase.id)) { error in
                guard let mappingError = error as? PersistenceError, case .invalidDomain = mappingError else {
                    return XCTFail("Expected domain reference error, got \(error)")
                }
            }
            let stored = try XCTUnwrap(store.freshContext().fetch(FetchDescriptor<PersistenceSchemaV1.SourceExcerptRecord>()).first)
            XCTAssertEqual(try PayloadCodec.decode(SourceExcerptDTO.self, from: stored.payload).sourceVersionID, dto.sourceVersionID)
        }
    }

    func testSnapshotWithMissingCriterionRevisionIsRejected() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            var dto = CaseGraphDTO(f.context())
            dto.caseRevisions[0].criteria[0].id = StoredID(EntityID<CriterionRevision>(), kind: "CriterionRevision")
            let store = try LocalCaseStore.inMemory()
            XCTAssertThrowsError(try store.saveCase(dto.domain()))
            XCTAssertTrue(try store.listCases().isEmpty)
        }
    }

    func testEvaluationWithMissingSnapshotIsRejected() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            var dto = CaseGraphDTO(f.context())
            dto.caseEvaluations[0].caseRevisionID = StoredID(EntityID<CaseRevision>(), kind: "CaseRevision")
            let store = try LocalCaseStore.inMemory()
            XCTAssertThrowsError(try store.saveCase(dto.domain()))
            XCTAssertTrue(try store.listCases().isEmpty)
        }
    }

    func testInvalidStoredStatusIsStructuredMappingError() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(f.context())
            let context = store.freshContext()
            let row = try XCTUnwrap(context.fetch(FetchDescriptor<PersistenceSchemaV1.CaseRecord>()).first)
            var dto = try PayloadCodec.decode(CaseDTO.self, from: row.payload)
            dto.workflowState = "inventedStatus"
            row.payload = try PayloadCodec.encode(dto); try context.save()
            XCTAssertThrowsError(try store.loadCase(id: f.politicalCase.id)) { error in
                XCTAssertEqual(error as? PersistenceError, .invalidEnum(type: "CaseWorkflowState", value: "inventedStatus"))
            }
        }
    }

    func testCorruptPayloadIsNotDefaulted() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(f.context())
            let context = store.freshContext()
            let row = try XCTUnwrap(context.fetch(FetchDescriptor<PersistenceSchemaV1.SourceExcerptRecord>()).first)
            row.payload = Data([0, 1, 2]); try context.save()
            XCTAssertThrowsError(try store.loadCase(id: f.politicalCase.id)) { error in
                guard let mappingError = error as? PersistenceError, case .corruptPayload = mappingError else {
                    return XCTFail("Expected corrupt payload error, got \(error)")
                }
            }
        }
    }

    func testUnsupportedPayloadVersionIsRejected() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(f.context())
            let context = store.freshContext()
            let row = try XCTUnwrap(context.fetch(FetchDescriptor<PersistenceSchemaV1.SourceExcerptRecord>()).first)
            row.formatVersion = 99; try context.save()
            XCTAssertThrowsError(try store.loadCase(id: f.politicalCase.id)) { error in
                XCTAssertEqual(error as? PersistenceError, .unsupportedFormat(99))
            }
        }
    }

    func testRowAndPayloadIdentityMustAgree() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(f.context())
            let context = store.freshContext()
            let row = try XCTUnwrap(context.fetch(FetchDescriptor<PersistenceSchemaV1.SourceExcerptRecord>()).first)
            var dto = try PayloadCodec.decode(SourceExcerptDTO.self, from: row.payload)
            dto.id = StoredID(EntityID<SourceExcerpt>(), kind: "SourceExcerpt")
            row.payload = try PayloadCodec.encode(dto); try context.save()
            XCTAssertThrowsError(try store.loadCase(id: f.politicalCase.id)) { error in
                XCTAssertEqual(error as? PersistenceError, .identityMismatch(kind: "SourceExcerpt", id: f.excerpt.id.rawValue))
            }
        }
    }

    func testWrongManifestIDTypeIsRejected() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(f.context())
            let context = store.freshContext()
            let row = try XCTUnwrap(context.fetch(FetchDescriptor<PersistenceSchemaV1.CaseRecord>()).first)
            var manifest = try PayloadCodec.decode(CaseManifest.self, from: row.manifest)
            manifest.sourceVersions[0].kind = "ResearchTask"
            row.manifest = try PayloadCodec.encode(manifest); try context.save()
            XCTAssertThrowsError(try store.loadCase(id: f.politicalCase.id)) { error in
                XCTAssertEqual(error as? PersistenceError,
                    .wrongIDType(expected: "SourceVersion", actual: "ResearchTask", id: f.sourceVersion.id.rawValue))
            }
        }
    }

    func testEmptyKnownTextIsRejectedDuringMapping() throws {
        let f = try PersistenceFixture()
        var dto = SourceExcerptDTO(f.excerpt); dto.text = "  "
        XCTAssertThrowsError(try domainChange { try dto.domain() })
    }

    func testWrongTypedIDCannotBeReadAsEvidence() throws {
        let id = StoredID(EntityID<ResearchTask>(), kind: "ResearchTask")
        XCTAssertThrowsError(try id.domain(EvidenceLink.self, kind: "EvidenceLink"))
    }
    func testAuditWithMissingTargetIsRejected() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            var dto = CaseGraphDTO(f.context())
            let audit = AuditEntry(caseID: f.politicalCase.id,
                target: ObjectReference(kind: .sourceVersion, id: EntityID<SourceVersion>()),
                operation: text("Synthetic missing target"), author: .human(f.reviewer.id),
                occurredAt: PersistenceFixture.creation, reason: text("Synthetic validation failure"))
            dto.auditEntries.append(AuditEntryDTO(audit))
            let store = try LocalCaseStore.inMemory()
            XCTAssertThrowsError(try store.saveCase(dto.domain()))
            XCTAssertTrue(try store.listCases().isEmpty)
        }
    }

}
