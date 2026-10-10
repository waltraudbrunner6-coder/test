import Foundation
import PoliticalFactCheckCore
import PoliticalFactCheckVideoPlanning

public enum NarrationFormat: String, Codable { case wav }
public enum BuiltinNarrationVoice: String, Codable, CaseIterable { case marin, cedar, coral, alloy }
public enum NarrationLimits {
    public static let sceneBytes = 16 * 1024 * 1024
    public static let packageBytes = 128 * 1024 * 1024
    public static let manifestBytes = 1024 * 1024
}
public enum NarrationError: Error, Equatable {
    case missingAPIKey, invalidRequest, badRequest, authenticationFailed, permissionDenied, timeout
    case rateLimited, serviceUnavailable, transportFailure, cancelled, emptyResponse, responseTooLarge
    case nonAudioResponse, corruptWAV, invalidManifest, unsupportedSchema, hashMismatch, missingScene
    case unsafePath, collision, storageFailure, staleInput, alreadyExists, generationInProgress, inputUnavailable
    case playbackFailure
    public var displayMessage: String {
        switch self {
        case .missingAPIKey: return "OpenAI API key is not configured"
        case .invalidRequest: return "Die Sprachkonfiguration oder der freigegebene Text ist ungültig."
        case .badRequest: return "Der Sprachprovider hat Modell oder Anfrage abgelehnt; kein automatischer Modellwechsel."
        case .authenticationFailed: return "Authentifizierung beim Sprachprovider fehlgeschlagen."
        case .permissionDenied: return "Der Sprachprovider verweigert den Zugriff."
        case .timeout: return "Zeitüberschreitung bei der Sprachgenerierung."
        case .rateLimited: return "Anfragelimit des Sprachproviders erreicht."
        case .serviceUnavailable: return "Der Sprachprovider ist derzeit nicht verfügbar."
        case .transportFailure: return "Die Sprachübertragung ist fehlgeschlagen."
        case .cancelled: return "Sprachgenerierung abgebrochen."
        case .emptyResponse: return "Der Sprachprovider hat keine Audiodaten geliefert."
        case .responseTooLarge: return "Die Audiodaten überschreiten das erlaubte Größenlimit."
        case .nonAudioResponse: return "Die Antwort enthält keine WAV-Audiodaten."
        case .corruptWAV: return "Eine WAV-Datei ist beschädigt, unlesbar oder besitzt keine gültige Dauer."
        case .invalidManifest: return "Das Sprachpaket oder seine Timeline ist ungültig."
        case .unsupportedSchema: return "Diese Sprachpaket-Version wird nicht unterstützt."
        case .hashMismatch: return "Eine Audiodatei stimmt nicht mit ihrem SHA-256 überein."
        case .missingScene: return "Eine Audiodatei fehlt im Sprachpaket."
        case .unsafePath: return "Das Sprachpaket enthält einen unsicheren Dateipfad."
        case .collision: return "Am Ziel liegt bereits ein anderer oder unsicherer Dateieintrag."
        case .storageFailure: return "Das Sprachpaket konnte nicht vollständig gespeichert oder gelesen werden."
        case .staleInput: return "Der Fall oder das Skript hat sich während der Sprachgenerierung geändert. Temporäre Dateien wurden verworfen."
        case .alreadyExists: return "Eine Sprachspur ist bereits vorhanden. Neu erzeugen muss ausdrücklich angefordert werden."
        case .generationInProgress: return "Eine Sprachspur wird bereits erzeugt."
        case .inputUnavailable: return "Ein aktuelles, menschlich freigegebenes Skript ist für die Sprachspur erforderlich."
        case .playbackFailure: return "Die lokale Audiodatei konnte nicht abgespielt werden."
        }
    }
}
public struct NarrationSettings: Equatable {
    public let voice: BuiltinNarrationVoice
    public let speed: Double
    public init(voice: BuiltinNarrationVoice = .marin, speed: Double = 1) { self.voice = voice; self.speed = speed }
}
public struct NarrationRequest: Equatable {
    public let scenePosition: Int
    public let statementID: EntityID<ScriptStatement>
    public let text: String
    public let voice: BuiltinNarrationVoice
    public let speed: Double
    public let format: NarrationFormat
    public let instructions: String
    public init(scenePosition: Int, statementID: EntityID<ScriptStatement>, text: String,
                voice: BuiltinNarrationVoice = .marin, speed: Double = 1, format: NarrationFormat = .wav,
                instructions: String) {
        self.scenePosition = scenePosition; self.statementID = statementID; self.text = text
        self.voice = voice; self.speed = speed; self.format = format; self.instructions = instructions
    }
    public func validate() throws {
        guard scenePosition >= 0, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              speed.isFinite, (0.85...1.15).contains(speed), instructions == (try NarrationStyleV1.instructions()) else {
            throw NarrationError.invalidRequest
        }
    }
}
public struct NarrationAudio: Equatable {
    public let bytes: Data
    public let format: NarrationFormat
    public let contentType: String?
    public init(bytes: Data, format: NarrationFormat = .wav, contentType: String? = nil) {
        self.bytes = bytes; self.format = format; self.contentType = contentType
    }
}
public protocol NarrationProvider {
    var identifier: NonEmptyText { get }
    var model: String { get }
    func synthesize(request: NarrationRequest) async throws -> NarrationAudio
}
public enum NarrationStyleV1 {
    public static let version = "narration-style-v1"
    public static func instructions() throws -> String {
        guard let url = Bundle.module.url(forResource: version, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { throw NarrationError.invalidRequest }
        return text
    }
}

/// UUIDs are the unchanged raw values of the typed domain IDs at this Codable file boundary.
public struct NarrationPackageManifestV1: Codable, Equatable {
    public let schemaVersion: Int
    public let caseID: UUID
    public let evaluationID: UUID
    public let scriptID: UUID
    public let scriptVersion: Int
    public let providerIdentifier: String
    public let model: String
    public let voice: BuiltinNarrationVoice
    public let speed: Double
    public let styleVersion: String
    public let audioFormat: NarrationFormat
    public let createdAt: Date
    public let targetDurationSeconds: Double
    public let actualDurationSeconds: Double
    public let requiresAIDisclosure: Bool
    public let disclosureText: String
    public let scenes: [NarrationSceneAudioV1]
    public let captionCues: [CaptionCueV1]
}
public struct NarrationSceneAudioV1: Codable, Equatable {
    public let position: Int
    public let statementID: UUID
    public let relativeFilename: String
    public let sha256: String
    public let narrationTextSHA256: String
    public let byteCount: Int
    public let startSeconds: Double
    public let endSeconds: Double
    public let measuredDurationSeconds: Double
    public let estimatedDurationSeconds: Double
}
public struct CaptionCueV1: Codable, Equatable {
    public let index: Int
    public let statementID: UUID
    public let scenePosition: Int
    public let startSeconds: Double
    public let endSeconds: Double
    public let text: String
}
public struct NarrationPackageV1: Equatable {
    public let manifest: NarrationPackageManifestV1
    /// Local ephemeral path, never part of the manifest.
    public let directory: URL
    public var durationWithinPublicationRange: Bool { (30...60).contains(manifest.actualDurationSeconds) }
    public func readyForRendering(handoff: VideoScriptHandoffV1?) -> Bool {
        guard let handoff else { return false }
        return durationWithinPublicationRange && (try? NarrationManifestValidation.validate(manifest, handoff: handoff)) != nil
    }
}
