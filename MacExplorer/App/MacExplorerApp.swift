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
    @StateObject private var appModel: AppModel
    @State private var showFullDiskAccessPrompt = false
    @State private var showDerivedDataWarning = false

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
            .task {
                // DerivedData builds get a separate TCC identity — Desktop prompts return even with FDA on /Applications.
                if FullDiskAccess.shouldWarnDerivedDataMismatch {
                    showDerivedDataWarning = true
                    return
                }
                if FullDiskAccess.shouldPromptOnLaunch {
                    showFullDiskAccessPrompt = true
                }
            }
            .alert(
                L10n.tr("alert.fda.derived.title"),
                isPresented: $showDerivedDataWarning
            ) {
                if FullDiskAccess.applicationsCopyExists {
                    Button(L10n.tr("alert.fda.derived.open_apps")) {
                        FullDiskAccess.markDerivedDataWarned()
                        FullDiskAccess.openApplicationsCopy()
                    }
                }
                Button(L10n.tr("alert.fda.open_settings")) {
                    FullDiskAccess.markDerivedDataWarned()
                    FullDiskAccess.openSystemSettings()
                }
                Button(L10n.tr("alert.fda.later"), role: .cancel) {
                    FullDiskAccess.markDerivedDataWarned()
                }
            } message: {
                Text(L10n.tr("alert.fda.derived.message %@", FullDiskAccess.currentAppPath))
            }
            .alert(
                L10n.tr("alert.fda.title"),
                isPresented: $showFullDiskAccessPrompt
            ) {
                Button(L10n.tr("alert.fda.open_settings")) {
                    FullDiskAccess.markPrompted()
                    FullDiskAccess.openSystemSettings()
                }
                Button(L10n.tr("alert.fda.later"), role: .cancel) {
                    FullDiskAccess.markPrompted()
                }
            } message: {
                Text(L10n.tr("alert.fda.message"))
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
