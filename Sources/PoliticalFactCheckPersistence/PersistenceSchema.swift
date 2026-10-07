import Foundation
import SwiftData

public enum PersistenceSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        [CaseRecord.self, PromiseRecord.self, PromiseRevisionRecord.self, EvaluationCriterionRecord.self, CriterionRevisionRecord.self, ActionOrDevelopmentRecord.self, ActionRevisionRecord.self, ActionParticipationRecord.self, EvidenceLinkRecord.self, ResearchTaskRecord.self, AuditEntryRecord.self, ScriptDraftRecord.self, ScriptStatementRecord.self, CaseRevisionRecord.self, CriterionEvaluationRecord.self, CaseEvaluationRecord.self, MethodologyVersionRecord.self, ReviewerIdentityRecord.self, ActorRecord.self, ActorAffiliationRecord.self, SourceRecord.self, SourceVersionRecord.self, SourceExcerptRecord.self]
    }

    @Model
    final class CaseRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        var manifest: Data
        init(id: UUID, payload: Data, manifest: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
            self.manifest = manifest
        }
    }

    @Model
    final class PromiseRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class PromiseRevisionRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class EvaluationCriterionRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class CriterionRevisionRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class ActionOrDevelopmentRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class ActionRevisionRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class ActionParticipationRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class EvidenceLinkRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class ResearchTaskRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class AuditEntryRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class ScriptDraftRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class ScriptStatementRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class CaseRevisionRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class CriterionEvaluationRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class CaseEvaluationRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class MethodologyVersionRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class ReviewerIdentityRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class ActorRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class ActorAffiliationRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class SourceRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class SourceVersionRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }

    @Model
    final class SourceExcerptRecord {
        var id: UUID
        var payload: Data
        var formatVersion: Int
        init(id: UUID, payload: Data) {
            self.id = id
            self.payload = payload
            self.formatVersion = 1
        }
    }
}

public enum PersistenceMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [PersistenceSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}
