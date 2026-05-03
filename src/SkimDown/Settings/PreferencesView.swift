import SwiftUI

struct PreferencesView: View {
    @ObservedObject var viewModel: PreferencesViewModel
    var fontPickerCoordinator: FontPickerCoordinator

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            themesTab
                .tabItem {
                    Label("Themes", systemImage: "paintbrush")
                }

            editingTab
                .tabItem {
                    Label("Editing", systemImage: "textformat")
                }
        }
        .frame(width: 480, height: 400)
    }

    // MARK: - General

    private var generalTab: some View {
        VStack(spacing: 0) {
            settingsGrid {
                settingsRow("Sidebar Position") {
                    Picker("", selection: $viewModel.sidebarPosition) {
                        Text("Left").tag(SidebarPosition.left)
                        Text("Right").tag(SidebarPosition.right)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }
            Spacer()
        }
    }

    // MARK: - Themes

    private var themesTab: some View {
        VStack(spacing: 0) {
            settingsGrid {
                settingsRow("Appearance") {
                    Picker("", selection: $viewModel.theme) {
                        Text("System").tag(AppTheme.system)
                        Text("Light").tag(AppTheme.light)
                        Text("Dark").tag(AppTheme.dark)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }

                Divider()

                settingsRow("Theme") {
                    VStack(alignment: .leading, spacing: 8) {
                        themePicker
                        themeActionButtons
                    }
                }
            }
            Spacer()
        }
    }

    private var themePicker: some View {
        Picker("", selection: Binding(
            get: { viewModel.customThemeID ?? "" },
            set: { newID in
                if newID.isEmpty {
                    viewModel.selectTheme(nil)
                } else {
                    let theme = viewModel.availableThemes.first { $0.id == newID }
                    viewModel.selectTheme(theme)
                }
            }
        )) {
            Text("Default").tag("")
            ForEach(viewModel.availableThemes, id: \.id) { theme in
                Label {
                    Text(theme.name)
                } icon: {
                    Image(systemName: theme.colorScheme == .dark ? "moon.fill" : "sun.max.fill")
                }
                .tag(theme.id)
            }
        }
        .labelsHidden()
        .fixedSize()
    }

    private var themeActionButtons: some View {
        HStack(spacing: 8) {
            Button("Import…") {
                viewModel.importTheme()
            }
            .controlSize(.small)

            Button("Reveal in Finder") {
                viewModel.revealThemesFolder()
            }
            .controlSize(.small)
        }
    }

    // MARK: - Editing

    private var editingTab: some View {
        VStack(spacing: 0) {
            settingsGrid {
                settingsRow("Font") {
                    HStack(spacing: 8) {
                        Text(viewModel.fontDisplayName)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Button("Choose…") {
                            fontPickerCoordinator.showFontPanel(in: NSApp.keyWindow)
                        }
                        .controlSize(.small)

                        if viewModel.fontFamily != nil {
                            Button("Use Default") {
                                viewModel.resetFontFamily()
                            }
                            .controlSize(.small)
                        }
                    }
                }

                Divider()

                settingsRow("Font Size") {
                    HStack(spacing: 8) {
                        Slider(value: $viewModel.fontSize, in: 11...28, step: 1)
                            .frame(width: 160)

                        Text("\(Int(viewModel.fontSize)) pt")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)

                        if viewModel.fontSize != 16 {
                            Button("Reset") {
                                viewModel.resetFontSize()
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
            Spacer()
        }
    }

    // MARK: - Layout Helpers

    private func settingsGrid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 40)
        .padding(.top, 24)
    }

    private func settingsRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .frame(width: 110, alignment: .trailing)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
    }
}
