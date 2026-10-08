import Foundation
import PoliticalFactCheckCore
import PoliticalFactCheckExport

extension LocalCaseStore {
    /// Validated package only, one transaction, no merge/upsert of an existing case.
    public func importEditorialPackage(_ package: ValidatedEditorialPackage) throws -> EntityID<Case> {
        let graph = try package.domain()
        let caseID = package.summary.caseID
        try transaction("importEditorialPackage") { context in
            guard try readCase(caseID.rawValue, in: context) == nil else { throw EditorialPackageError.caseAlreadyExists }
            try writeCase(graph, in: context)
        }
        return caseID
    }
}
