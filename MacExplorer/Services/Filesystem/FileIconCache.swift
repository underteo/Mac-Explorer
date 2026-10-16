import AppKit
import UniformTypeIdentifiers

/// Process-wide icon cache so list/grid rows do not hit NSWorkspace on every redraw.
enum FileIconCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var images: [String: NSImage] = [:]

    /// System icon for a file URL (`NSWorkspace`), optionally washed with a Finder tag color.
    /// - Parameter folderOpen: Finder list/outline uses the open-folder glyph while expanded.
    static func icon(
        for url: URL,
        size: CGFloat = 16,
        tagColor: FinderColorTag? = nil,
        folderOpen: Bool = false
    ) -> NSImage {
        let tagKey = tagColor?.rawValue ?? "-"
        let openKey = folderOpen ? "open" : "closed"
        // v5: prefer named system artwork for Trash; safer resize.
        let key = "\(url.path)|\(Int(size))|\(tagKey)|\(openKey)|v5"
        lock.lock()
        if let cached = images[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let base: NSImage
        if isTrashURL(url), let trash = namedSystemImage(NSImage.trashEmptyName) {
            base = trash
        } else if folderOpen, isDirectory(url) {
            base = openFolderIcon()
        } else {
            base = NSWorkspace.shared.icon(forFile: url.path)
        }

        let sized = resized(base, to: size, tagColor: tagColor)

        lock.lock()
        images[key] = sized
        lock.unlock()
        return sized
    }

    static func icon(for item: FileItem, size: CGFloat = 16, folderOpen: Bool = false) -> NSImage {
        icon(
            for: item.url,
            size: size,
            tagColor: item.finderColorTags.first,
            folderOpen: folderOpen && item.isDirectory
        )
    }

    /// Untinted workspace icon (favorites, path bar).
    static func systemIcon(for url: URL, size: CGFloat = 16) -> NSImage {
        icon(for: url, size: size, tagColor: nil)
    }

    /// Sidebar location: named system artwork when available, else `NSWorkspace` for the URL, else SF fallback.
    static func sidebarIcon(for destination: SidebarDestination, size: CGFloat = 16) -> NSImage {
        let key = "sidebar|\(destination.rawValue)|\(Int(size))|v5"
        lock.lock()
        if let cached = images[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let base: NSImage
        if let name = destination.systemNSImageName, let named = namedSystemImage(name) {
            base = named
        } else if let url = destination.resolveURL() {
            if isTrashURL(url), let trash = namedSystemImage(NSImage.trashEmptyName) {
                base = trash
            } else {
                base = NSWorkspace.shared.icon(forFile: url.path)
            }
        } else if let symbol = NSImage(systemSymbolName: destination.systemImage, accessibilityDescription: nil) {
            base = symbol
        } else {
            base = namedSystemImage(NSImage.folderName) ?? NSWorkspace.shared.icon(for: .folder)
        }

        let sized = resized(base, to: size, tagColor: nil)
        lock.lock()
        images[key] = sized
        lock.unlock()
        return sized
    }

    private static func namedSystemImage(_ name: String) -> NSImage? {
        guard let image = NSImage(named: name), image.isValid else { return nil }
        // Copy so resizing never mutates the shared AppKit singleton.
        return image.copy() as? NSImage ?? image
    }

    private static func resized(_ base: NSImage, to size: CGFloat, tagColor: FinderColorTag?) -> NSImage {
        let target = NSSize(width: size, height: size)
        let sized = NSImage(size: target, flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .high
            base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            if let tagColor {
                tagColor.nsColor.withAlphaComponent(0.78).set()
                rect.fill(using: .sourceAtop)
            }
            return true
        }
        sized.isTemplate = base.isTemplate
        return sized
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private static func isTrashURL(_ url: URL) -> Bool {
        let trash = FullDiskAccess.trashDirectoryURL
        let standardized = url.standardizedFileURL
        return standardized == trash || standardized.path.hasPrefix(trash.path + "/")
    }

    /// System open-folder icon (Finder list view while a row is expanded).
    private static func openFolderIcon() -> NSImage {
        // HFS type 'ofld' — still the system open-folder artwork on modern macOS.
        let open = NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(0x6F666C64)))
        if open.isValid, open.size.width > 0 {
            return open
        }
        if let named = namedSystemImage(NSImage.folderName) {
            return named
        }
        return NSWorkspace.shared.icon(for: .folder)
    }
}
