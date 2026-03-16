import SwiftUI

@main
struct UserScriptsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @StateObject private var menuBarPanelController = MenuBarPanelController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(model)
                .environmentObject(menuBarPanelController)
                .preferredColorScheme(model.preferredColorScheme)
        } label: {
            Label(model.strings.appName, systemImage: model.overallSymbolName())
        }
        .menuBarExtraStyle(.window)

        Window(model.strings.consoleTitle, id: "manager") {
            ManagerRootView()
                .environmentObject(model)
                .preferredColorScheme(model.preferredColorScheme)
                .id("console-\(model.themePreference.rawValue)-\(model.languagePreference.rawValue)")
        }
        .defaultPosition(.center)
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button(model.strings.quit) {
                    _ = model.handleQuitCommand(allWindows: NSApp.windows)
                }
                .keyboardShortcut("q")
            }
        }

        Settings {
            AppSettingsView()
                .environmentObject(model)
                .preferredColorScheme(model.preferredColorScheme)
                .id("settings-\(model.themePreference.rawValue)-\(model.languagePreference.rawValue)")
        }
    }
}
