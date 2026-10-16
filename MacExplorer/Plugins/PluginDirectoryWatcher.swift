import Foundation

/// Debounced directory watch on the Plugins folder (hot reload without restart).
final class PluginDirectoryWatcher: @unchecked Sendable {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private var debounceWork: DispatchWorkItem?
    private let onChange: @MainActor () -> Void
    private let debounce: DispatchTimeInterval

    init(debounce: DispatchTimeInterval = .milliseconds(400), onChange: @MainActor @escaping () -> Void) {
        self.debounce = debounce
        self.onChange = onChange
    }

    func start(directoryURL: URL) {
        stop()
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fd = open(directoryURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        fileDescriptor = fd

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend, .attrib, .link],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            self?.scheduleReload()
        }
        src.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }
        source = src
        src.resume()
    }

    func stop() {
        debounceWork?.cancel()
        debounceWork = nil
        source?.cancel()
        source = nil
    }

    private func scheduleReload() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [onChange] in
            Task { @MainActor in
                onChange()
            }
        }
        debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: work)
    }
}
