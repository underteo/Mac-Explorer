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
        // v4: open-folder glyph while outline-expanded.
        let key = "\(url.path)|\(Int(size))|\(tagKey)|\(openKey)|v4"
        lock.lock()
        if let cached = images[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let base: NSImage
        if folderOpen, isDirectory(url) {
            base = openFolderIcon()
        } else {
            base = NSWorkspace.shared.icon(forFile: url.path)
        }

        let sized = NSImage(size: NSSize(width: size, height: size))
        sized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        base.draw(
            in: NSRect(origin: .zero, size: sized.size),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        if let tagColor {
            // Finder recolors the glyph strongly with the tag’s system color.
            tagColor.nsColor.withAlphaComponent(0.78).set()
            NSRect(origin: .zero, size: sized.size).fill(using: .sourceAtop)
        }
        sized.unlockFocus()
        sized.isTemplate = false

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

    /// Untinted workspace icon (sidebar locations, favorites).
    static func systemIcon(for url: URL, size: CGFloat = 16) -> NSImage {
        icon(for: url, size: size, tagColor: nil)
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    /// System open-folder icon (Finder list view while a row is expanded).
    private static func openFolderIcon() -> NSImage {
        // HFS type 'ofld' — still the system open-folder artwork on modern macOS.
        let open = NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(0x6F666C64)))
        if open.isValid, open.size.width > 0 {
            return open
        }
        if let named = NSImage(named: NSImage.folderName) {
            return named
        }
        return NSWorkspace.shared.icon(for: .folder)
    }
}
