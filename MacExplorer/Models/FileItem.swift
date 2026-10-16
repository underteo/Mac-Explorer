import Foundation
import UniformTypeIdentifiers

struct FileItem: Identifiable, Hashable, Sendable {
    var id: URL { url }
    let url: URL
    let name: String
    let isDirectory: Bool
    let isHidden: Bool
    let isSymbolicLink: Bool
    let fileSize: Int64?
    let contentModificationDate: Date?
    let creationDate: Date?
    let contentType: UTType?
    /// Finder tags (`tagNames` resource value) — shared with Finder.
    let tagNames: [String]
    /// Precomputed at listing time so table cells never hit UTType localization on redraw.
    let kindLabel: String

    init(
        url: URL,
        name: String,
        isDirectory: Bool,
        isHidden: Bool,
        isSymbolicLink: Bool,
        fileSize: Int64?,
        contentModificationDate: Date?,
        creationDate: Date?,
        contentType: UTType?,
        tagNames: [String] = [],
        kindLabel: String? = nil
    ) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.isHidden = isHidden
        self.isSymbolicLink = isSymbolicLink
        self.fileSize = fileSize
        self.contentModificationDate = contentModificationDate
        self.creationDate = creationDate
        self.contentType = contentType
        self.tagNames = tagNames
        if let kindLabel {
            self.kindLabel = kindLabel
        } else if isDirectory {
            self.kindLabel = "Folder"
        } else if let contentType {
            self.kindLabel = contentType.localizedDescription ?? contentType.identifier
        } else {
            self.kindLabel = url.pathExtension.isEmpty ? "Document" : url.pathExtension.uppercased()
        }
    }

    var finderColorTags: [FinderColorTag] {
        FinderTags.colors(in: tagNames)
    }

    /// Finder-like display name (optionally hide the extension for files).
    func listedName(showExtension: Bool) -> String {
        if isDirectory || showExtension { return name }
        let ns = name as NSString
        let ext = ns.pathExtension
        guard !ext.isEmpty, ns.length > ext.count + 1 else { return name }
        return ns.deletingPathExtension
    }

    static func pathExtension(of fileName: String) -> String {
        (fileName as NSString).pathExtension.lowercased()
    }

    static func isLikelyiCloudURL(_ url: URL) -> Bool {
        let path = url.path
        return path.contains("/Library/Mobile Documents/")
            || path.contains("com~apple~CloudDocs")
    }

    static func isTrashURL(_ url: URL) -> Bool {
        let trash = FullDiskAccess.trashDirectoryURL
        return url.standardizedFileURL == trash
            || url.standardizedFileURL.path.hasPrefix(trash.path + "/")
    }

    /// Lightweight folder item for context menus (e.g. empty-area plugins → current directory).
    static func representingDirectory(_ url: URL) -> FileItem {
        let standardized = url.standardizedFileURL
        return FileItem(
            url: standardized,
            name: standardized.lastPathComponent,
            isDirectory: true,
            isHidden: standardized.lastPathComponent.hasPrefix("."),
            isSymbolicLink: false,
            fileSize: nil,
            contentModificationDate: nil,
            creationDate: nil,
            contentType: .folder
        )
    }
}

enum PluginMenuTargets {
    /// Selection if non-empty; otherwise the folder currently shown in the pane.
    static func resolve(selected: [FileItem], directoryURL: URL) -> [FileItem] {
        if !selected.isEmpty { return selected }
        return [.representingDirectory(directoryURL)]
    }
}

enum FileSortKey: String, CaseIterable, Identifiable, Sendable {
    case name
    case date
    case size
    case kind

    var id: String { rawValue }
}

enum FilesystemError: Error, LocalizedError, Equatable {
    case missingPath(String)
    case permissionDenied(String)
    case notADirectory(String)
    case nameCollision(String)
    case operationFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingPath(let name):
            return L10n.tr("error.missing_path %@", name)
        case .permissionDenied(let name):
            return L10n.tr("error.permission_denied %@", name)
        case .notADirectory(let name):
            return L10n.tr("error.not_directory %@", name)
        case .nameCollision(let name):
            return L10n.tr("error.name_collision %@", name)
        case .operationFailed(let message):
            return message
        case .cancelled:
            return L10n.tr("error.cancelled")
        }
    }
}

enum FileTemplate: String, CaseIterable, Identifiable, Sendable {
    case plain
    case txt
    case markdown
    case json
    case csv
    case html

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .plain: return L10n.tr("template.file")
        case .txt: return "Text (.txt)"
        case .markdown: return "Markdown (.md)"
        case .json: return "JSON (.json)"
        case .csv: return "CSV (.csv)"
        case .html: return "HTML (.html)"
        }
    }

    var filename: String {
        switch self {
        case .plain: return "Untitled"
        case .txt: return "Untitled.txt"
        case .markdown: return "Untitled.md"
        case .json: return "Untitled.json"
        case .csv: return "Untitled.csv"
        case .html: return "Untitled.html"
        }
    }

    var contents: String {
        switch self {
        case .plain, .txt:
            return ""
        case .markdown:
            return "# Untitled\n\n"
        case .json:
            return "{\n  \n}\n"
        case .csv:
            return "column1,column2\n"
        case .html:
            return """
            <!DOCTYPE html>
            <html lang=\"en\">
            <head>
              <meta charset=\"utf-8\">
              <title>Untitled</title>
            </head>
            <body>
            </body>
            </html>

            """
        }
    }
}

