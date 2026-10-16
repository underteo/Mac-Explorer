import Foundation

struct FileInfoSummary: Equatable, Sendable {
    let url: URL
    let name: String
    let path: String
    let kind: String
    let sizeLabel: String
    let createdLabel: String
    let modifiedLabel: String
    let isDirectory: Bool
    let isSymbolicLink: Bool
    let permissionsLabel: String
}
