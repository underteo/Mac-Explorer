import AppKit
import Foundation

struct OpenWithApp: Identifiable, Hashable, Sendable {
    var id: URL { url }
    let url: URL
    let name: String
}

@MainActor
struct OpenWithService {
    func applications(for fileURL: URL) -> [OpenWithApp] {
        let urls = NSWorkspace.shared.urlsForApplications(toOpen: fileURL)
        return urls.map { url in
            let name = FileManager.default.displayName(atPath: url.path)
            return OpenWithApp(url: url, name: name)
        }
    }

    func open(_ fileURL: URL, with applicationURL: URL) throws {
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([fileURL], withApplicationAt: applicationURL, configuration: configuration) { _, error in
            _ = error
        }
    }

    func openWithPanel(for fileURL: URL) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = L10n.tr("open_with.choose")
        panel.begin { response in
            guard response == .OK, let appURL = panel.url else { return }
            try? self.open(fileURL, with: appURL)
        }
    }
}
