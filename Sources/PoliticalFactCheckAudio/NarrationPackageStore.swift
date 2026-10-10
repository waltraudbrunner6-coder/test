import Foundation
import PoliticalFactCheckVideoPlanning

/// One local writer; binary media never enters SwiftData or the political domain.
@MainActor public final class NarrationPackageStore {
    public let root: URL
    private let files = FileManager.default
    public init(root: URL) { self.root = root.standardizedFileURL.resolvingSymlinksInPath() }
    public static func applicationSupport() -> NarrationPackageStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return NarrationPackageStore(root: base.appendingPathComponent("PoliticalFactCheck/GeneratedMedia", isDirectory: true))
    }
    public func directory(for handoff: VideoScriptHandoffV1) -> URL {
        root.appendingPathComponent(handoff.caseID.rawValue.uuidString, isDirectory: true)
            .appendingPathComponent(handoff.scriptID.rawValue.uuidString, isDirectory: true)
            .appendingPathComponent("narration-v1", isDirectory: true)
    }
    public func exists(for handoff: VideoScriptHandoffV1) -> Bool { files.fileExists(atPath: directory(for: handoff).path) }

    public func generate(handoff: VideoScriptHandoffV1, provider: any NarrationProvider,
                         settings: NarrationSettings = .init(), regenerate: Bool = false, at date: Date = Date(),
                         progress: (Int, Int) -> Void = { _, _ in },
                         validateCurrent: () throws -> Void) async throws -> NarrationPackageV1 {
        try Task.checkCancellation(); try validateCurrent()
        guard !handoff.scenes.isEmpty else { throw NarrationError.invalidManifest }
        if exists(for: handoff) && !regenerate { throw NarrationError.alreadyExists }
        let staging = root.appendingPathComponent(".tmp-" + UUID().uuidString, isDirectory: true)
        do {
            try requireSafeLocation(root)
            try files.createDirectory(at: staging, withIntermediateDirectories: true)
        } catch let error as NarrationError { throw error }
        catch { throw NarrationError.storageFailure }
        defer { try? files.removeItem(at: staging) }
        do {
            let instructions = try NarrationStyleV1.instructions()
            var scenes: [NarrationSceneAudioV1] = [], end: Double = 0, totalBytes = 0
            for (index, scene) in handoff.scenes.enumerated() {
                try Task.checkCancellation(); progress(index + 1, handoff.scenes.count)
                let request = NarrationRequest(scenePosition: scene.position, statementID: scene.statementID,
                    text: scene.narrationText, voice: settings.voice, speed: settings.speed, instructions: instructions)
                try request.validate()
                let audio = try await provider.synthesize(request: request)
                try Task.checkCancellation()
                guard audio.format == .wav, audio.bytes.count <= NarrationLimits.sceneBytes else { throw NarrationError.responseTooLarge }
                totalBytes += audio.bytes.count
                guard totalBytes <= NarrationLimits.packageBytes else { throw NarrationError.responseTooLarge }
                try WAVInspection.requireHeader(audio.bytes)
                let name = NarrationManifestValidation.filename(position: scene.position)
                try NarrationManifestValidation.safeFilename(name)
                let url = staging.appendingPathComponent(name)
                guard !files.fileExists(atPath: url.path) else { throw NarrationError.invalidManifest }
                try audio.bytes.write(to: url, options: .atomic)
                let measurement = try WAVInspection.measure(at: url), nextEnd = end + measurement.durationSeconds
                scenes.append(NarrationSceneAudioV1(position: scene.position, statementID: scene.statementID.rawValue,
                    relativeFilename: name, sha256: WAVInspection.hash(audio.bytes),
                    narrationTextSHA256: WAVInspection.hash(Data(scene.narrationText.utf8)), byteCount: audio.bytes.count,
                    startSeconds: end, endSeconds: nextEnd, measuredDurationSeconds: measurement.durationSeconds,
                    estimatedDurationSeconds: scene.estimatedDurationSeconds))
                end = nextEnd
            }
            let captions = try SubtitleTimelineV1.build(handoff: handoff, scenes: scenes)
            let manifest = NarrationPackageManifestV1(schemaVersion: 1, caseID: handoff.caseID.rawValue,
                evaluationID: handoff.evaluationID.rawValue, scriptID: handoff.scriptID.rawValue, scriptVersion: handoff.scriptVersion,
                providerIdentifier: provider.identifier.value, model: provider.model, voice: settings.voice, speed: settings.speed,
                styleVersion: NarrationStyleV1.version, audioFormat: .wav, createdAt: date,
                targetDurationSeconds: handoff.targetDurationSeconds, actualDurationSeconds: end,
                requiresAIDisclosure: true, disclosureText: "KI-generierte Stimme", scenes: scenes, captionCues: captions)
            try NarrationManifestValidation.validate(manifest, handoff: handoff)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let bytes = try encoder.encode(manifest)
            guard bytes.count <= NarrationLimits.manifestBytes else { throw NarrationError.invalidManifest }
            try bytes.write(to: staging.appendingPathComponent("manifest.json"), options: .atomic)
            _ = try read(directory: staging, handoff: handoff) // validate the actual staged files before publication
            try Task.checkCancellation(); try validateCurrent()
            // No await between fresh domain/token validation and atomic filesystem publication.
            let destination = directory(for: handoff)
            try finalize(staging: staging, destination: destination, regenerate: regenerate)
            return NarrationPackageV1(manifest: manifest, directory: destination)
        } catch is CancellationError { throw CancellationError() }
        catch let error as NarrationError { throw error }
        catch { throw NarrationError.storageFailure }
    }

    public func load(handoff: VideoScriptHandoffV1) throws -> NarrationPackageV1? {
        let path = directory(for: handoff)
        guard files.fileExists(atPath: path.path) else { return nil }
        return try read(directory: path, handoff: handoff)
    }
    private func read(directory: URL, handoff: VideoScriptHandoffV1) throws -> NarrationPackageV1 {
        do {
            try requireSafeLocation(directory)
            let manifestURL = directory.appendingPathComponent("manifest.json")
            try requireSafeLocation(manifestURL)
            guard files.fileExists(atPath: manifestURL.path) else { throw NarrationError.invalidManifest }
            let data = try boundedRead(manifestURL, limit: NarrationLimits.manifestBytes)
            let manifest = try decodeManifest(data)
            try NarrationManifestValidation.validate(manifest, handoff: handoff)
            let names = Set(try files.contentsOfDirectory(atPath: directory.path))
            guard names.isSubset(of: Set(manifest.scenes.map { $0.relativeFilename } + ["manifest.json"])) else { throw NarrationError.invalidManifest }
            for scene in manifest.scenes {
                let url = directory.appendingPathComponent(scene.relativeFilename)
                guard files.fileExists(atPath: url.path) else { throw NarrationError.missingScene }
                try requireSafeLocation(url)
                let bytes = try boundedRead(url, limit: NarrationLimits.sceneBytes)
                guard bytes.count == scene.byteCount, WAVInspection.hash(bytes) == scene.sha256 else { throw NarrationError.hashMismatch }
                try WAVInspection.requireHeader(bytes)
                let measured = try WAVInspection.measure(at: url)
                guard abs(measured.durationSeconds - scene.measuredDurationSeconds) < 0.0000001 else { throw NarrationError.invalidManifest }
            }
            return NarrationPackageV1(manifest: manifest, directory: directory)
        } catch let error as NarrationError { throw error }
        catch { throw NarrationError.invalidManifest }
    }
    public func audioURL(package: NarrationPackageV1, scenePosition: Int, handoff: VideoScriptHandoffV1) throws -> URL {
        guard let current = try load(handoff: handoff), current.manifest == package.manifest,
              let scene = current.manifest.scenes.first(where: { $0.position == scenePosition }) else { throw NarrationError.playbackFailure }
        return current.directory.appendingPathComponent(scene.relativeFilename)
    }
    private func finalize(staging: URL, destination: URL, regenerate: Bool) throws {
        try requireSafeLocation(destination)
        try files.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !files.fileExists(atPath: destination.path) {
            try files.moveItem(at: staging, to: destination); return
        }
        guard regenerate else { throw NarrationError.alreadyExists }
        guard (try files.attributesOfItem(atPath: destination.path))[.type] as? FileAttributeType == .typeDirectory else { throw NarrationError.collision }
        let backup = ".backup-" + UUID().uuidString
        let backupURL = destination.deletingLastPathComponent().appendingPathComponent(backup)
        do {
            _ = try files.replaceItemAt(destination, withItemAt: staging, backupItemName: backup,
                options: [.usingNewMetadataOnly, .withoutDeletingBackupItem])
            try? files.removeItem(at: backupURL)
        } catch {
            // Preserve the prior complete directory if replacement reported failure.
            if files.fileExists(atPath: backupURL.path) {
                if files.fileExists(atPath: destination.path) { try files.removeItem(at: destination) }
                try files.moveItem(at: backupURL, to: destination)
            }
            throw NarrationError.storageFailure
        }
    }
    private func requireSafeLocation(_ url: URL) throws {
        let expectedRoot = root.standardizedFileURL.path
        let target = url.standardizedFileURL.path
        guard target == expectedRoot || target.hasPrefix(expectedRoot + "/") else { throw NarrationError.unsafePath }
        // Reject symlink components including ancestors of the configured root. Do not follow a
        // manifest filename or an existing destination outside the media root.
        var cursor = url.standardizedFileURL
        while cursor.path != "/" {
            if let attributes = try? files.attributesOfItem(atPath: cursor.path), attributes[.type] as? FileAttributeType == .typeSymbolicLink {
                throw NarrationError.unsafePath
            }
            cursor.deleteLastPathComponent()
        }
    }
    private func boundedRead(_ url: URL, limit: Int) throws -> Data {
        let attributes = try files.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber, size.int64Value <= Int64(limit) else { throw NarrationError.invalidManifest }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let bytes = try handle.read(upToCount: limit + 1) ?? Data()
        guard bytes.count <= limit else { throw NarrationError.responseTooLarge }
        return bytes
    }
    private func decodeManifest(_ bytes: Data) throws -> NarrationPackageManifestV1 {
        guard let object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              Set(object.keys) == ["schemaVersion", "caseID", "evaluationID", "scriptID", "scriptVersion", "providerIdentifier", "model", "voice", "speed", "styleVersion", "audioFormat", "createdAt", "targetDurationSeconds", "actualDurationSeconds", "requiresAIDisclosure", "disclosureText", "scenes", "captionCues"],
              let scenes = object["scenes"] as? [[String: Any]], let cues = object["captionCues"] as? [[String: Any]],
              scenes.allSatisfy({ Set($0.keys) == ["position", "statementID", "relativeFilename", "sha256", "narrationTextSHA256", "byteCount", "startSeconds", "endSeconds", "measuredDurationSeconds", "estimatedDurationSeconds"] }),
              cues.allSatisfy({ Set($0.keys) == ["index", "statementID", "scenePosition", "startSeconds", "endSeconds", "text"] }) else { throw NarrationError.invalidManifest }
        return try JSONDecoder().decode(NarrationPackageManifestV1.self, from: bytes)
    }
}
