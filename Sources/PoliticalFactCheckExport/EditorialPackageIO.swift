import Foundation

/// Filesystem boundary only: no database, network, source retrieval or implicit overwrite.
public enum EditorialPackageIO {
    public static func write(_ contents: EditorialPackageContents, to destination: URL) throws {
        let manager = FileManager.default
        guard destination.isFileURL, destination.pathExtension == EditorialPackage.directoryExtension else { throw EditorialPackageError.writeFailure }
        guard !manager.fileExists(atPath: destination.path) else { throw EditorialPackageError.destinationExists }
        _ = try EditorialPackage.validate(files: contents.files)
        let parent = destination.deletingLastPathComponent()
        let temporary = parent.appendingPathComponent(".politicalfactcheck-\(UUID().uuidString)", isDirectory: true)
        do {
            try manager.createDirectory(at: temporary, withIntermediateDirectories: false)
            defer { try? manager.removeItem(at: temporary) }
            for name in EditorialPackage.payloadFilenames + ["manifest.json"] {
                try contents.files[name]!.write(to: temporary.appendingPathComponent(name), options: .atomic)
            }
            // Move the completed sibling directory only after every file has been written.
            try manager.moveItem(at: temporary, to: destination)
        } catch { throw EditorialPackageError.writeFailure }
    }
    public static func read(from directory: URL) throws -> ValidatedEditorialPackage {
        guard directory.isFileURL, directory.pathExtension == EditorialPackage.directoryExtension else { throw EditorialPackageError.readFailure }
        let manager = FileManager.default
        let expected = Set(EditorialPackage.payloadFilenames + ["manifest.json"])
        var files: [String: Data] = [:]
        do {
            let info = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard info.isDirectory == true, info.isSymbolicLink != true else { throw EditorialPackageError.readFailure }
            let names = try manager.contentsOfDirectory(atPath: directory.path)
            guard Set(names) == expected else { throw EditorialPackageError.missingFile }
            var total = 0
            for name in names.sorted() {
                let url = directory.appendingPathComponent(name)
                let info = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard info.isRegularFile == true, info.isSymbolicLink != true,
                      let size = info.fileSize, size <= 16 * 1024 * 1024 else { throw EditorialPackageError.readFailure }
                let data = try Data(contentsOf: url)
                total += data.count
                guard data.count <= 16 * 1024 * 1024, total <= 64 * 1024 * 1024 else { throw EditorialPackageError.readFailure }
                files[name] = data
            }
        } catch let error as EditorialPackageError { throw error }
        catch { throw EditorialPackageError.readFailure }
        return try EditorialPackage.validate(files: files)
    }
}
