import Foundation
import CryptoKit
import PoliticalFactCheckCore
import PoliticalFactCheckScripting

public struct EditorialFileV1: Codable, Equatable {
    public let filename: String
    public let sha256: String
    public let byteCount: Int
}
public struct EditorialManifestV1: Codable, Equatable {
    public let schemaVersion: Int
    public let packageType: String
    public let exportFormatVersion: String
    public let exportedAt: Date
    public let caseID: UUID
    public let caseEvaluationID: UUID
    public let caseRevisionID: UUID
    public let scriptDraftID: UUID
    public let scriptVersion: Int
    public let methodologyVersionID: UUID
    public let methodologyVersion: String
    public let methodologyHash: String
    public let files: [EditorialFileV1]
}
public struct EditorialPackageContents {
    public let manifest: EditorialManifestV1
    public let files: [String: Data]
}
public struct ValidatedEditorialPackage {
    public let manifest: EditorialManifestV1
    public let archive: PortableCaseArchiveV1
    public let summary: EditorialPackageSummary
    public func domain() throws -> DomainContext { try archive.domain() }
}

public enum EditorialPackage {
    public static let packageType = "PoliticalFactCheck Editorial Package"
    public static let directoryExtension = "politicalfactcheck"
    public static let payloadFilenames = ["README.md", "case-archive.json", "case-report.json", "methodology.md", "script.md", "sources.md", "storyboard.md"]
    public static func sha256(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    public static func canonicalMethodology() throws -> Data {
        guard let url = Bundle.module.url(forResource: "methodology-v1.0", withExtension: "md"),
              let data = try? Data(contentsOf: url), sha256(data) == (try MethodologyV1.version()).hash?.sha256 else {
            throw EditorialPackageError.methodologyConflict
        }
        return data
    }
    public static func summary(graph: DomainContext, evaluationID: EntityID<CaseEvaluation>, scriptID: EntityID<ScriptDraft>, exportedAt: Date? = nil) throws -> EditorialPackageSummary {
        let input = try EditorialValidation.publicationInput(graph: graph, evaluationID: evaluationID, scriptID: scriptID)
        try checkMethodology(input.methodology)
        guard let script = graph.find(scriptID) else { throw EditorialPackageError.invalidScript }
        let report = EditorialCaseReportV1(graph: graph, input: input, script: script)
        return EditorialPackageSummary(caseID: graph.cases[0].id, evaluationID: evaluationID, scriptID: scriptID,
            title: report.title, category: input.evaluation.category, cutoff: input.evaluation.cutoff,
            methodologyVersion: input.methodology.version.value, scriptVersion: script.version, scriptStatus: script.status,
            statementCount: script.statementIDs.count, sourceCount: report.sourceVersions.count,
            excerptCount: report.excerpts.count, schemaVersion: 1, exportedAt: exportedAt)
    }
    public static func create(graph: DomainContext, evaluationID: EntityID<CaseEvaluation>, scriptID: EntityID<ScriptDraft>, exportedAt: Date = Date()) throws -> EditorialPackageContents {
        let input = try EditorialValidation.publicationInput(graph: graph, evaluationID: evaluationID, scriptID: scriptID)
        try checkMethodology(input.methodology)
        let archive = try PortableCaseArchiveV1(graph)
        guard let script = graph.find(scriptID) else { throw EditorialPackageError.invalidScript }
        let report = EditorialCaseReportV1(graph: graph, input: input, script: script)
        var files = try EditorialDocuments.render(graph: graph, input: input, script: script, report: report)
        files["case-archive.json"] = try PortableJSON.encode(archive)
        files["case-report.json"] = try PortableJSON.encode(report)
        files["methodology.md"] = try canonicalMethodology()
        try checkPrivacy(files)
        let manifest = EditorialManifestV1(schemaVersion: 1, packageType: packageType, exportFormatVersion: "1",
            exportedAt: exportedAt, caseID: graph.cases[0].id.rawValue, caseEvaluationID: input.evaluation.id.rawValue,
            caseRevisionID: input.snapshotID.rawValue, scriptDraftID: script.id.rawValue, scriptVersion: script.version,
            methodologyVersionID: input.methodology.id.rawValue, methodologyVersion: input.methodology.version.value,
            methodologyHash: sha256(files["methodology.md"]!),
            files: payloadFilenames.map { EditorialFileV1(filename: $0, sha256: sha256(files[$0]!), byteCount: files[$0]!.count) })
        files["manifest.json"] = try PortableJSON.encode(manifest)
        return EditorialPackageContents(manifest: manifest, files: files)
    }
    public static func validate(files: [String: Data]) throws -> ValidatedEditorialPackage {
        guard let data = files["manifest.json"] else { throw EditorialPackageError.missingFile }
        let manifest = try PortableJSON.decode(EditorialManifestV1.self, from: data)
        guard manifest.schemaVersion == 1, manifest.exportFormatVersion == "1" else { throw EditorialPackageError.unsupportedVersion }
        guard manifest.packageType == packageType else { throw EditorialPackageError.invalidPackage }
        guard Set(files.keys) == Set(payloadFilenames + ["manifest.json"]),
              manifest.files.map({ $0.filename }).sorted() == payloadFilenames else { throw EditorialPackageError.missingFile }
        for entry in manifest.files {
            guard let bytes = files[entry.filename] else { throw EditorialPackageError.missingFile }
            guard bytes.count == entry.byteCount, sha256(bytes) == entry.sha256 else { throw EditorialPackageError.hashConflict }
        }
        guard files["methodology.md"] == (try canonicalMethodology()),
              sha256(files["methodology.md"]!) == manifest.methodologyHash else { throw EditorialPackageError.methodologyConflict }
        try checkPrivacy(files)
        let archive = try PortableJSON.decode(PortableCaseArchiveV1.self, from: files["case-archive.json"]!)
        let graph = try archive.domain()
        let input = try EditorialValidation.publicationInput(graph: graph, evaluationID: EntityID(manifest.caseEvaluationID), scriptID: EntityID(manifest.scriptDraftID))
        try checkMethodology(input.methodology)
        guard graph.cases[0].id.rawValue == manifest.caseID,
              input.snapshotID.rawValue == manifest.caseRevisionID,
              input.methodology.id.rawValue == manifest.methodologyVersionID,
              input.methodology.version.value == manifest.methodologyVersion,
              input.methodology.hash?.sha256 == manifest.methodologyHash,
              let script = graph.find(EntityID<ScriptDraft>(manifest.scriptDraftID)), script.version == manifest.scriptVersion else {
            throw EditorialPackageError.invalidReference
        }
        let decodedReport = try PortableJSON.decode(EditorialCaseReportV1.self, from: files["case-report.json"]!)
        let expectedReport = EditorialCaseReportV1(graph: graph, input: input, script: script)
        guard decodedReport == expectedReport else { throw EditorialPackageError.invalidPackage }
        // Human-readable documents must describe this exact archive, not a separately altered text.
        let documents = try EditorialDocuments.render(graph: graph, input: input, script: script, report: expectedReport)
        for (name, bytes) in documents where files[name] != bytes { throw EditorialPackageError.invalidPackage }
        return ValidatedEditorialPackage(manifest: manifest, archive: archive,
            summary: try summary(graph: graph, evaluationID: input.evaluation.id, scriptID: script.id, exportedAt: manifest.exportedAt))
    }
    private static func checkMethodology(_ value: MethodologyVersion) throws {
        guard value == (try MethodologyV1.version()) else { throw EditorialPackageError.methodologyConflict }
        _ = try canonicalMethodology()
    }
    private static func checkPrivacy(_ files: [String: Data]) throws {
        // Typed format excludes runtime/network state. Reject obvious accidentally pasted credential dumps.
        let forbidden = ["OPENAI_API_KEY", "Authorization:", "\"Authorization\"", "\\\"Authorization\\\"", "Bearer ", "safety_identifier", "politicalFactCheck.openAISafetyIdentifier", "previous_response_id", "\\\"input_text\\\"", "test-key-not-real"]
        for data in files.values {
            guard let text = String(data: data, encoding: .utf8) else { throw EditorialPackageError.invalidJSON }
            if forbidden.contains(where: { text.localizedCaseInsensitiveContains($0) }) { throw EditorialPackageError.sensitiveContent }
        }
    }
}
