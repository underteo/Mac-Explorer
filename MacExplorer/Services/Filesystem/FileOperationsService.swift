import Foundation
import AppKit

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

struct FileOperationsService: @unchecked Sendable {
    private var fileManager: FileManager { .default }

    init() {}

    func createFolder(named name: String, in directory: URL) throws -> URL {
        let destination = uniqueURL(for: name, in: directory)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: false)
        return destination
    }

    func createFile(template: FileTemplate, in directory: URL) throws -> URL {
        let destination = uniqueURL(for: template.filename, in: directory)
        do {
            // Prefer write(to:) over createFile: empty Data can fail with createFile on some volumes.
            try Data(template.contents.utf8).write(to: destination, options: .withoutOverwriting)
        } catch {
            throw FilesystemError.operationFailed(error.localizedDescription)
        }
        return destination
    }

    func rename(item: URL, to newName: String) throws -> URL {
        let destination = item.deletingLastPathComponent().appendingPathComponent(newName)
        if fileManager.fileExists(atPath: destination.path) {
            throw FilesystemError.nameCollision(newName)
        }
        try fileManager.moveItem(at: item, to: destination)
        return destination
    }

    func copy(items: [URL], to directory: URL, overwrite: Bool = false) throws {
        for item in items {
            let dest = directory.appendingPathComponent(item.lastPathComponent)
            if fileManager.fileExists(atPath: dest.path) {
                if overwrite {
                    try fileManager.removeItem(at: dest)
                } else {
                    throw FilesystemError.nameCollision(item.lastPathComponent)
                }
            }
            try fileManager.copyItem(at: item, to: dest)
        }
    }

    func move(items: [URL], to directory: URL, overwrite: Bool = false) throws {
        for item in items {
            let dest = directory.appendingPathComponent(item.lastPathComponent)
            if fileManager.fileExists(atPath: dest.path) {
                if overwrite {
                    try fileManager.removeItem(at: dest)
                } else {
                    throw FilesystemError.nameCollision(item.lastPathComponent)
                }
            }
            try fileManager.moveItem(at: item, to: dest)
        }
    }

    func moveToTrash(_ items: [URL]) throws {
        for item in items {
            var resulting: NSURL?
            try fileManager.trashItem(at: item, resultingItemURL: &resulting)
        }
    }

    func copyWithProgress(
        items: [URL],
        to directory: URL,
        overwrite: Bool = false,
        progress: @MainActor @escaping (TransferProgress) -> Void,
        isCancelled: @MainActor @escaping () -> Bool
    ) async throws {
        let total = items.count
        for (index, item) in items.enumerated() {
            if await isCancelled() { throw FilesystemError.cancelled }
            try copy(items: [item], to: directory, overwrite: overwrite)
            await progress(TransferProgress(completed: index + 1, total: total))
        }
    }

    func moveWithProgress(
        items: [URL],
        to directory: URL,
        overwrite: Bool = false,
        progress: @MainActor @escaping (TransferProgress) -> Void,
        isCancelled: @MainActor @escaping () -> Bool
    ) async throws {
        let total = items.count
        for (index, item) in items.enumerated() {
            if await isCancelled() { throw FilesystemError.cancelled }
            try move(items: [item], to: directory, overwrite: overwrite)
            await progress(TransferProgress(completed: index + 1, total: total))
        }
    }

    func revealInFinder(_ urls: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func duplicate(_ item: URL) throws -> URL {
        let directory = item.deletingLastPathComponent()
        let destination = uniqueURL(for: item.lastPathComponent, in: directory)
        try fileManager.copyItem(at: item, to: destination)
        return destination
    }

    func copyPathToPasteboard(_ urls: [URL]) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(urls.map(\.path) as [NSString])
    }

    func makeInfo(for url: URL) throws -> FileInfoSummary {
        let values = try url.resourceValues(forKeys: [
            .nameKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey,
            .contentTypeKey,
            .fileResourceTypeKey
        ])
        let isDirectory = values.isDirectory ?? false
        let size: Int64
        if isDirectory {
            size = (try? directorySize(of: url)) ?? 0
        } else {
            size = Int64(values.fileSize ?? 0)
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let attrs = try fileManager.attributesOfItem(atPath: url.path)
        let perms = attrs[.posixPermissions] as? NSNumber
        let permString: String
        if let perms {
            permString = String(format: "%o", perms.uint16Value)
        } else {
            permString = "—"
        }
        return FileInfoSummary(
            url: url,
            name: values.name ?? url.lastPathComponent,
            path: url.path,
            kind: values.contentType?.localizedDescription
                ?? (isDirectory ? "Folder" : (url.pathExtension.uppercased().nilIfEmpty ?? "Document")),
            sizeLabel: ByteCountFormatter.string(fromByteCount: size, countStyle: .file),
            createdLabel: values.creationDate.map { dateFormatter.string(from: $0) } ?? "—",
            modifiedLabel: values.contentModificationDate.map { dateFormatter.string(from: $0) } ?? "—",
            isDirectory: isDirectory,
            isSymbolicLink: values.isSymbolicLink ?? false,
            permissionsLabel: permString
        )
    }

    private func directorySize(of url: URL) throws -> Int64 {
        var total: Int64 = 0
        if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) {
            for case let fileURL as URL in enumerator {
                let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                if values.isDirectory != true {
                    total += Int64(values.fileSize ?? 0)
                }
            }
        }
        return total
    }

    private func uniqueURL(for filename: String, in directory: URL) -> URL {
        var candidate = directory.appendingPathComponent(filename)
        if !fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }
        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var index = 2
        while true {
            let name = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            candidate = directory.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }
}
