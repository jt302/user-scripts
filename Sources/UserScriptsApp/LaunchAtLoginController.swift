import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController {
    var isSupported: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    var isEnabled: Bool {
        guard #available(macOS 13.0, *), isSupported else {
            return false
        }
        return SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else {
            return
        }
        guard isSupported else {
            throw NSError(domain: "UserScripts", code: 1, userInfo: [NSLocalizedDescriptionKey: "Launch at login requires running from an app bundle."])
        }
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
