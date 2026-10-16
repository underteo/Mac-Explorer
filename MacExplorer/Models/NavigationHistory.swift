import Foundation

struct NavigationHistory: Hashable, Sendable {
    private(set) var backStack: [URL]
    private(set) var forwardStack: [URL]
    private(set) var current: URL

    init(initial: URL) {
        self.current = initial
        self.backStack = []
        self.forwardStack = []
    }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    mutating func navigate(to url: URL) {
        guard url.standardizedFileURL != current.standardizedFileURL else { return }
        backStack.append(current)
        current = url
        forwardStack.removeAll()
    }

    mutating func goBack() -> URL? {
        guard let previous = backStack.popLast() else { return nil }
        forwardStack.append(current)
        current = previous
        return current
    }

    mutating func goForward() -> URL? {
        guard let next = forwardStack.popLast() else { return nil }
        backStack.append(current)
        current = next
        return current
    }
}
