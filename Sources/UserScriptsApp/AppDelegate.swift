import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let consoleWindowCoordinator = ConsoleWindowCloseCoordinator()
    private weak var consoleWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        consoleWindowCoordinator.model?.handleAppTerminationRequest(allWindows: sender.windows) ?? .terminateNow
    }

    @MainActor
    func registerConsoleWindow(_ window: NSWindow, model: AppModel) {
        consoleWindow = window
        consoleWindowCoordinator.attach(to: window, model: model)
    }
}
