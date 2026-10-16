import SwiftUI

@main
struct MacExplorerApp: App {
    var body: some Scene {
        WindowGroup(id: "explorer") {
            ExplorerWindowRoot()
                .environmentObject(AppSettings.shared)
        }
        .defaultSize(width: 1100, height: 700)
        .commands {
            ExplorerCommands()
        }

        Settings {
            SettingsWindowRoot()
                .environmentObject(AppSettings.shared)
        }
    }
}

/// One `AppModel` per explorer window so New Window is independent.
private struct ExplorerWindowRoot: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openSettings) private var openSettings
    @StateObject private var appModel: AppModel

    init() {
        _appModel = StateObject(
            wrappedValue: AppModel(rootURL: AppSettings.shared.resolveNewWindowURL())
        )
    }

    var body: some View {
        ExplorerRootView()
            .environmentObject(appModel)
            .environmentObject(settings)
            .scaleEffect(settings.interfaceZoom, anchor: .center)
            .frame(minWidth: 800, minHeight: 500)
            .id(settings.language)
            .onReceive(NotificationCenter.default.publisher(for: .explorerOpenSettings)) { _ in
                openSettings()
            }
    }
}

private struct SettingsWindowRoot: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var appModel = AppModel()

    var body: some View {
        SettingsRootView()
            .environmentObject(appModel)
            .environmentObject(settings)
            .frame(minWidth: 520, minHeight: 420)
            .id(settings.language)
    }
}
