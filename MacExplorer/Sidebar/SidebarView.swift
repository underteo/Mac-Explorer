import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        List {
            ForEach(settings.orderedVisibleSidebarDestinations) { destination in
                switch destination {
                case .favorites:
                    favoritesSection
                case .recents:
                    recentsSection
                default:
                    locationRow(destination)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        .onReceive(NotificationCenter.default.publisher(for: .explorerNavigate)) { note in
            guard let url = note.object as? URL else { return }
            navigate(to: url)
        }
    }

    @ViewBuilder
    private var favoritesSection: some View {
        Section(L10n.tr("sidebar.section.favorites")) {
            if app.favoriteItems.isEmpty {
                Text(L10n.tr("sidebar.favorites.empty"))
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(app.favoriteItems) { favorite in
                    Button {
                        navigate(to: favorite.url)
                    } label: {
                        Label(favorite.name, systemImage: "star.fill")
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(L10n.tr("favorites.remove"), role: .destructive) {
                            app.removeFavorite(id: favorite.id)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentsSection: some View {
        Section(L10n.tr("sidebar.section.recents")) {
            if app.recentItems.isEmpty {
                Text(L10n.tr("sidebar.recents.empty"))
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(app.recentItems) { recent in
                    Button {
                        navigate(to: recent.url)
                    } label: {
                        Label(recent.name, systemImage: "clock")
                    }
                    .buttonStyle(.plain)
                }
                Button(L10n.tr("sidebar.recents.clear")) {
                    app.recentsStore.clear()
                    app.recentItems = []
                }
                .font(.caption)
            }
        }
    }

    @ViewBuilder
    private func locationRow(_ destination: SidebarDestination) -> some View {
        Button {
            if let url = destination.resolveURL() {
                navigate(to: url)
            }
        } label: {
            Label(destination.localizedTitle, systemImage: destination.systemImage)
        }
        .buttonStyle(.plain)
    }

    private func navigate(to url: URL) {
        Task { @MainActor in
            var pane = app.primaryPane
            await PaneController.navigate(&pane, to: url, using: app.filesystem)
            app.primaryPane = pane
            var tab = app.selectedTab
            tab.title = url.lastPathComponent
            app.selectedTab = tab
            app.recordRecent(url)
        }
    }
}

extension Notification.Name {
    static let explorerNavigate = Notification.Name("explorerNavigate")
}
