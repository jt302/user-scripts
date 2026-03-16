import AppKit

@MainActor
final class MenuBarPanelController: ObservableObject {
    weak var window: NSWindow?

    func attach(window: NSWindow) {
        self.window = window
    }

    func close() {
        window?.orderOut(nil)
        window?.close()
    }

    func closeAndDeactivate() {
        close()
        NSApp.hide(nil)
    }
}
