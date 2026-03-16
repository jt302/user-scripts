import Foundation

struct AppPaths {
    let applicationSupportDirectory: URL
    let scriptsFileURL: URL
    let logsDirectory: URL

    static var `default`: AppPaths {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("UserScripts", isDirectory: true)
        return AppPaths(
            applicationSupportDirectory: base,
            scriptsFileURL: base.appendingPathComponent("scripts.json"),
            logsDirectory: base.appendingPathComponent("Logs", isDirectory: true)
        )
    }

    func prepare() throws {
        try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
    }
}
