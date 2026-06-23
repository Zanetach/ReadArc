import SwiftUI

struct PreferencesView: View {
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @AppStorage("appLanguage") private var languageRaw = AppLanguage.system.rawValue
    @Environment(\.appLanguage) private var language

    private var appearanceMode: Binding<AppAppearanceMode> {
        Binding(
            get: { AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system },
            set: { mode in
                appearanceModeRaw = mode.rawValue
                AppAppearanceController.apply(mode)
                if mode == .system {
                    AppAppearanceController.requestSystemAppearanceRefresh()
                }
            }
        )
    }

    private var appLanguage: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: languageRaw) ?? .system },
            set: { languageRaw = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section(language.text("settings.general")) {
                Picker(language.text("appearance"), selection: appearanceMode) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        Text(language.text(mode.titleKey))
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker(language.text("language"), selection: appLanguage) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(language.text(option.titleKey))
                            .tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(language.text("updates.title")) {
                HStack {
                    Text(language.text("updates.currentVersion"))
                    Spacer()
                    Text(Bundle.main.readArcDisplayVersion)
                        .foregroundStyle(.secondary)
                }

                Button(language.text("updates.check")) {
                    AppUpdateChecker.checkForUpdates(language: language)
                }
            }
        }
        .padding(24)
        .frame(width: 440)
        .navigationTitle(language.text("settings.title"))
    }
}
