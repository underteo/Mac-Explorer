import AppKit
import SwiftUI

struct SettingsRootView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(settings)
                .tabItem {
                    Label(L10n.tr("settings.general"), systemImage: "gearshape")
                }

            SidebarSettingsView()
                .environmentObject(settings)
                .tabItem {
                    Label(L10n.tr("settings.sidebar"), systemImage: "sidebar.left")
                }

            PluginsSettingsView()
                .environmentObject(app)
                .tabItem {
                    Label(L10n.tr("settings.plugins"), systemImage: "puzzlepiece.extension")
                }
        }
        .padding()
        // Rebuild labels when language preference changes.
        .id(settings.language)
    }
}

struct SidebarSettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("settings.sidebar.header"))
                .foregroundStyle(.secondary)
                .font(.callout)

            Text(L10n.tr("settings.sidebar.reorder_hint"))
                .foregroundStyle(.secondary)
                .font(.caption)

            List {
                ForEach(settings.orderedSidebarDestinations) { item in
                    Toggle(isOn: settings.bindingSidebarItem(item)) {
                        Label(item.localizedTitle, systemImage: item.systemImage)
                    }
                }
                .onMove(perform: settings.moveSidebarItem)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            HStack {
                Spacer()
                Button(L10n.tr("settings.sidebar.reset_order")) {
                    settings.resetSidebarOrder()
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    private let zoomRange: ClosedRange<Double> = 0.5...1.5

    var body: some View {
        Form {
            Section {
                Picker(L10n.tr("settings.new_window_shows"), selection: $settings.newWindowLocation) {
                    ForEach(AppSettings.NewWindowLocation.allCases) { location in
                        Label(location.displayName, systemImage: location.systemImage)
                            .tag(location)
                    }
                }

                Toggle(L10n.tr("settings.open_folders_in_tabs"), isOn: $settings.openFoldersInTabs)
            }

            Section {
                Picker(L10n.tr("settings.language"), selection: $settings.language) {
                    ForEach(AppSettings.LanguagePreference.allCases) { preference in
                        Text(preference.displayName).tag(preference)
                    }
                }
            } footer: {
                Text(L10n.tr("settings.language.footer"))
                    .foregroundStyle(.secondary)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L10n.tr("settings.zoom"))
                        Spacer()
                        Text(settings.zoomPercentLabel)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $settings.interfaceZoom, in: zoomRange, step: 0.1) {
                        Text(L10n.tr("settings.zoom"))
                    } minimumValueLabel: {
                        Text("50%").font(.caption2).foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Text("150%").font(.caption2).foregroundStyle(.secondary)
                    }
                    .accessibilityValue(settings.zoomPercentLabel)

                    Button(L10n.tr("settings.zoom.reset")) {
                        settings.interfaceZoom = 1.0
                    }
                    .buttonStyle(.borderless)
                }
            } footer: {
                Text(L10n.tr("settings.zoom.footer"))
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(L10n.tr("settings.privacy.open_fda")) {
                    PrivacySettingsOpener.openFullDiskAccess()
                }
                Button(L10n.tr("settings.privacy.open_files_folders")) {
                    PrivacySettingsOpener.openFilesAndFolders()
                }
            } header: {
                Text(L10n.tr("settings.privacy.header"))
            } footer: {
                Text(L10n.tr("settings.privacy.footer"))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Opens System Settings privacy panes (macOS cannot grant these from the app itself).
enum PrivacySettingsOpener {
    static func openFullDiskAccess() {
        openPrivacyPane(candidates: [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
        ])
    }

    static func openFilesAndFolders() {
        openPrivacyPane(candidates: [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_FilesAndFolders",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders",
        ])
    }

    private static func openPrivacyPane(candidates: [String]) {
        for string in candidates {
            guard let url = URL(string: string) else { continue }
            if NSWorkspace.shared.open(url) { return }
        }
    }
}

struct PluginsSettingsView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.tr("settings.plugins.header"))
                    .font(.headline)
                Spacer()
                Button(L10n.tr("plugins.install")) {
                    app.pluginManager.presentInstallPanel()
                }
                Button(L10n.tr("settings.plugins.reload")) {
                    app.pluginManager.reload()
                }
                Button(L10n.tr("settings.plugins.reveal")) {
                    app.pluginManager.revealPluginsFolder()
                }
            }

            if app.pluginManager.plugins.isEmpty {
                Text(L10n.tr("settings.plugins.empty"))
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(app.pluginManager.plugins) { plugin in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.tr(plugin.manifest.name))
                                    .font(.body.weight(.semibold))
                                Text(plugin.manifest.id)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let error = plugin.loadError {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                } else {
                                    Text(L10n.tr("settings.plugins.version %@", plugin.manifest.version))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Toggle(L10n.tr("settings.plugins.enabled"), isOn: Binding(
                                get: { plugin.isEnabled && plugin.loadError == nil },
                                set: { app.pluginManager.setEnabled($0, pluginID: plugin.manifest.id) }
                            ))
                            .disabled(plugin.loadError != nil)
                            .labelsHidden()
                            .accessibilityLabel(L10n.tr("settings.plugins.enabled"))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { app.pluginManager.reload() }
    }
}
