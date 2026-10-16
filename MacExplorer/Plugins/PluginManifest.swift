import Foundation

struct PluginManifest: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var version: String
    var match: PluginMatchRules
    var menu: [PluginMenuNode]
    /// Relative executable path inside the plugin folder, or an absolute path that must stay under the plugin root.
    var executable: String?
    /// Optional URL scheme template, e.g. `myapp://open?path={path}`
    var urlTemplate: String?

    enum CodingKeys: String, CodingKey {
        case id, name, version, match, menu, executable, urlTemplate
    }
}

struct PluginMatchRules: Codable, Equatable, Sendable {
    var extensions: [String]?
    var foldersOnly: Bool?
    var filesOnly: Bool?
    var requireMultiSelect: Bool?
    var allowMultiSelect: Bool?

    func matches(items: [FileItem]) -> Bool {
        guard !items.isEmpty else { return false }
        if requireMultiSelect == true, items.count < 2 { return false }
        if allowMultiSelect == false, items.count > 1 { return false }
        if foldersOnly == true, items.contains(where: { !$0.isDirectory }) { return false }
        if filesOnly == true, items.contains(where: { $0.isDirectory }) { return false }
        if let extensions, !extensions.isEmpty {
            let normalized = Set(extensions.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) })
            let allMatch = items.allSatisfy { item in
                if item.isDirectory { return foldersOnly == true }
                return normalized.contains(item.url.pathExtension.lowercased())
            }
            if !allMatch { return false }
        }
        return true
    }
}

indirect enum PluginMenuNode: Codable, Equatable, Sendable, Identifiable {
    case action(PluginMenuAction)
    case submenu(title: String, children: [PluginMenuNode])

    var id: String {
        switch self {
        case .action(let action): return action.id
        case .submenu(let title, _): return "submenu.\(title)"
        }
    }

    enum CodingKeys: String, CodingKey {
        case type, title, children, id, action, shortcut
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "submenu":
            let title = try container.decode(String.self, forKey: .title)
            let children = try container.decode([PluginMenuNode].self, forKey: .children)
            self = .submenu(title: title, children: children)
        case "action":
            let action = try PluginMenuAction(from: decoder)
            self = .action(action)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown menu type \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .submenu(let title, let children):
            try container.encode("submenu", forKey: .type)
            try container.encode(title, forKey: .title)
            try container.encode(children, forKey: .children)
        case .action(let action):
            try container.encode("action", forKey: .type)
            try container.encode(action.id, forKey: .id)
            try container.encode(action.title, forKey: .title)
            try container.encodeIfPresent(action.action, forKey: .action)
            try container.encodeIfPresent(action.shortcut, forKey: .shortcut)
        }
    }
}

struct PluginMenuAction: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var title: String
    var action: String?
    var shortcut: String?
}
