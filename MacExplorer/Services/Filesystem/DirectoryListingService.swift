import Foundation
import UniformTypeIdentifiers

struct DirectoryListingService: @unchecked Sendable {
    var includeHiddenFiles: Bool = false

    init(includeHiddenFiles: Bool = false) {
        self.includeHiddenFiles = includeHiddenFiles
    }

    private var fileManager: FileManager { .default }

    func listContents(
        of url: URL,
        sortKey: FileSortKey = .name,
        ascending: Bool = true,
        keepFoldersOnTop: Bool = true
    ) throws -> [FileItem] {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw FilesystemError.missingPath(url.lastPathComponent)
        }
        guard isDirectory.boolValue else {
            throw FilesystemError.notADirectory(url.lastPathComponent)
        }

        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isHiddenKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .contentTypeKey,
            .nameKey,
            .tagNamesKey
        ]

        do {
            let urls = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: keys,
                options: includeHiddenFiles ? [] : [.skipsHiddenFiles]
            )
            let items = try urls.map { try makeItem(from: $0) }
            return sort(items, by: sortKey, ascending: ascending, keepFoldersOnTop: keepFoldersOnTop)
        } catch let error as NSError {
            if error.domain == NSPOSIXErrorDomain && (error.code == EACCES || error.code == EPERM) {
                throw FilesystemError.permissionDenied(url.lastPathComponent)
            }
            if error.code == NSFileReadNoPermissionError {
                throw FilesystemError.permissionDenied(url.lastPathComponent)
            }
            throw FilesystemError.operationFailed(error.localizedDescription)
        }
    }

    func makeItem(from url: URL) throws -> FileItem {
        let values = try url.resourceValues(forKeys: [
            .isDirectoryKey,
            .isHiddenKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .contentTypeKey,
            .nameKey,
            .tagNamesKey
        ])
        return FileItem(
            url: url,
            name: values.name ?? url.lastPathComponent,
            isDirectory: values.isDirectory ?? false,
            isHidden: values.isHidden ?? url.lastPathComponent.hasPrefix("."),
            isSymbolicLink: values.isSymbolicLink ?? false,
            fileSize: values.isDirectory == true ? nil : Int64(values.fileSize ?? 0),
            contentModificationDate: values.contentModificationDate,
            creationDate: values.creationDate,
            contentType: values.contentType,
            tagNames: values.tagNames ?? []
        )
    }

    func sort(
        _ items: [FileItem],
        by key: FileSortKey,
        ascending: Bool,
        keepFoldersOnTop: Bool = true
    ) -> [FileItem] {
        let sorted = items.sorted { lhs, rhs in
            if keepFoldersOnTop, lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            let result: ComparisonResult
            switch key {
            case .name:
                result = lhs.name.localizedStandardCompare(rhs.name)
            case .date:
                let ld = lhs.contentModificationDate ?? .distantPast
                let rd = rhs.contentModificationDate ?? .distantPast
                result = ld == rd ? .orderedSame : (ld < rd ? .orderedAscending : .orderedDescending)
            case .size:
                let ls = lhs.fileSize ?? -1
                let rs = rhs.fileSize ?? -1
                result = ls == rs ? .orderedSame : (ls < rs ? .orderedAscending : .orderedDescending)
            case .kind:
                result = lhs.kindLabel.localizedStandardCompare(rhs.kindLabel)
            }
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
        return sorted
    }
}
