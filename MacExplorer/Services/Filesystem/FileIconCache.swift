import AppKit

/// Process-wide icon cache so list/grid rows do not hit NSWorkspace on every redraw.
enum FileIconCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var images: [String: NSImage] = [:]

    static func icon(for url: URL, size: CGFloat = 16) -> NSImage {
        let key = "\(url.path)|\(Int(size))"
        lock.lock()
        if let cached = images[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let image = NSWorkspace.shared.icon(forFile: url.path)
        let copy = (image.copy() as? NSImage) ?? image
        copy.size = NSSize(width: size, height: size)

        lock.lock()
        images[key] = copy
        lock.unlock()
        return copy
    }
}
