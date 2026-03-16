import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}

@MainActor
final class ConsoleWindowCloseCoordinator: NSObject, NSWindowDelegate {
    weak var model: AppModel?
    weak var window: NSWindow?

    @MainActor @objc
    func handleCloseButton(_ sender: Any?) {
        _ = model?.handleConsoleWindowCloseRequest(window: window)
    }

    @MainActor
    func attach(to window: NSWindow, model: AppModel) {
        self.window = window
        self.model = model
        if window.delegate !== self {
            window.delegate = self
        }
        if let button = window.standardWindowButton(.closeButton) {
            button.target = self
            button.action = #selector(handleCloseButton(_:))
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        model?.handleConsoleWindowCloseRequest(window: sender) ?? true
    }
}
