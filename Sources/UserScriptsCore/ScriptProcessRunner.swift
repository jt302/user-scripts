import Foundation
import Darwin

public enum ScriptTerminationReason: String, Codable, Equatable, Sendable {
    case exit
    case stopped
    case failedToLaunch
}

public struct RunningScriptHandle: Equatable, Sendable {
    public let scriptID: UUID
    public let pid: Int32?
    public let startedAt: Date
    public let logURL: URL

    public init(scriptID: UUID, pid: Int32?, startedAt: Date, logURL: URL) {
        self.scriptID = scriptID
        self.pid = pid
        self.startedAt = startedAt
        self.logURL = logURL
    }
}

public struct ScriptRunRecord: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let scriptID: UUID
    public let startedAt: Date
    public let endedAt: Date
    public let exitCode: Int32
    public let terminationReason: ScriptTerminationReason
    public let logURL: URL

    public init(
        id: UUID = UUID(),
        scriptID: UUID,
        startedAt: Date,
        endedAt: Date,
        exitCode: Int32,
        terminationReason: ScriptTerminationReason,
        logURL: URL
    ) {
        self.id = id
        self.scriptID = scriptID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.exitCode = exitCode
        self.terminationReason = terminationReason
        self.logURL = logURL
    }

    public var succeeded: Bool {
        terminationReason == .exit && exitCode == 0
    }
}

public enum ScriptProcessRunnerError: LocalizedError {
    case alreadyRunning
    case notRunning
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            "The script is already running."
        case .notRunning:
            "The script is not running."
        case let .launchFailed(message):
            message
        }
    }
}

public actor ScriptProcessRunner {
    private final class RunningContext: @unchecked Sendable {
        enum Kind {
            case direct(Process)
            case privileged(pid: Int32, statusURL: URL)
        }

        let scriptID: UUID
        let startedAt: Date
        let logURL: URL
        let kind: Kind
        let outputHandle: FileHandle?
        var stopRequested = false
        var waitTask: Task<ScriptRunRecord, Error>?
        var timeoutTask: Task<Void, Never>?

        init(
            scriptID: UUID,
            startedAt: Date,
            logURL: URL,
            kind: Kind,
            outputHandle: FileHandle?
        ) {
            self.scriptID = scriptID
            self.startedAt = startedAt
            self.logURL = logURL
            self.kind = kind
            self.outputHandle = outputHandle
        }
    }

    private var activeRuns: [UUID: RunningContext] = [:]
    private var completedRuns: [UUID: ScriptRunRecord] = [:]

    public init() {}

    public func start(_ script: ScriptDefinition, logDirectory: URL) async throws -> RunningScriptHandle {
        if activeRuns[script.id] != nil {
            throw ScriptProcessRunnerError.alreadyRunning
        }

        try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)

        let startedAt = Date()
        let timestamp = ISO8601DateFormatter().string(from: startedAt).replacingOccurrences(of: ":", with: "-")
        let logURL = logDirectory.appendingPathComponent("\(script.id.uuidString)-\(timestamp).log")
        do {
            try Data().write(to: logURL)
        } catch {
            throw ScriptProcessRunnerError.launchFailed("Unable to create log file at \(logURL.path): \(error.localizedDescription)")
        }

        let context: RunningContext
        let pid: Int32?
        if script.requiresPrivileges {
            let launched = try Self.launchPrivileged(script: script, logURL: logURL, logDirectory: logDirectory, startedAt: startedAt)
            context = launched.context
            pid = launched.pid
        } else {
            let outputHandle = try FileHandle(forWritingTo: logURL)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: script.shell.launchPath)
            process.arguments = ["-lc", script.command]
            process.currentDirectoryURL = URL(fileURLWithPath: script.workingDirectory, isDirectory: true)
            process.environment = ProcessInfo.processInfo.environment.merging(script.environmentVariables) { _, new in new }
            process.standardOutput = outputHandle
            process.standardError = outputHandle
            try process.run()

            context = RunningContext(
                scriptID: script.id,
                startedAt: startedAt,
                logURL: logURL,
                kind: .direct(process),
                outputHandle: outputHandle
            )
            pid = process.processIdentifier
        }

        let runner = self
        context.waitTask = Task {
            let record = try await Self.monitor(context: context)
            await runner.finish(record, for: script.id)
            return record
        }

        if let timeoutSeconds = script.timeoutSeconds {
            context.timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(timeoutSeconds))
                _ = try? await self?.stop(scriptID: script.id)
            }
        }

        activeRuns[script.id] = context
        return RunningScriptHandle(scriptID: script.id, pid: pid, startedAt: startedAt, logURL: logURL)
    }

    public func waitForExit(of scriptID: UUID) async throws -> ScriptRunRecord {
        if let activeContext = activeRuns[scriptID], let waitTask = activeContext.waitTask {
            return try await waitTask.value
        }

        if let completed = completedRuns[scriptID] {
            return completed
        }

        throw ScriptProcessRunnerError.notRunning
    }

    public func stop(scriptID: UUID) async throws -> Bool {
        guard let context = activeRuns[scriptID] else {
            return false
        }

        context.stopRequested = true
        switch context.kind {
        case let .direct(process):
            guard process.isRunning else {
                return false
            }
            process.terminate()
            return true
        case let .privileged(pid, _):
            try Self.runAppleScriptCommand("if kill -0 \(pid) >/dev/null 2>&1; then kill -TERM \(pid); fi")
            return true
        }
    }

    private func finish(_ record: ScriptRunRecord, for scriptID: UUID) {
        activeRuns[scriptID]?.timeoutTask?.cancel()
        activeRuns[scriptID] = nil
        completedRuns[scriptID] = record
    }

    private static func monitor(context: RunningContext) async throws -> ScriptRunRecord {
        switch context.kind {
        case let .direct(process):
            process.waitUntilExit()
            try? context.outputHandle?.close()
            return ScriptRunRecord(
                scriptID: context.scriptID,
                startedAt: context.startedAt,
                endedAt: Date(),
                exitCode: process.terminationStatus,
                terminationReason: context.stopRequested ? .stopped : .exit,
                logURL: context.logURL
            )
        case let .privileged(pid, statusURL):
            while isProcessRunning(pid: pid) {
                try await Task.sleep(for: .milliseconds(300))
            }

            let exitCode = Int32((try? String(contentsOf: statusURL).trimmingCharacters(in: .whitespacesAndNewlines)).flatMap(Int.init) ?? (context.stopRequested ? 143 : 1))
            return ScriptRunRecord(
                scriptID: context.scriptID,
                startedAt: context.startedAt,
                endedAt: Date(),
                exitCode: exitCode,
                terminationReason: context.stopRequested ? .stopped : .exit,
                logURL: context.logURL
            )
        }
    }

    private static func launchPrivileged(
        script: ScriptDefinition,
        logURL: URL,
        logDirectory: URL,
        startedAt: Date
    ) throws -> (context: RunningContext, pid: Int32) {
        let pidURL = logDirectory.appendingPathComponent("\(script.id.uuidString).pid")
        let statusURL = logDirectory.appendingPathComponent("\(script.id.uuidString).status")
        try? FileManager.default.removeItem(at: pidURL)
        try? FileManager.default.removeItem(at: statusURL)

        let exports = script.environmentVariables
            .sorted(by: { $0.key < $1.key })
            .map { "export \($0.key)=\(shellQuote($0.value))" }
            .joined(separator: "; ")

        let launchCommand = [
            "cd \(shellQuote(script.workingDirectory))",
            exports.isEmpty ? nil : exports,
            "( \(shellQuote(script.shell.launchPath)) -lc \(shellQuote(script.command)) > \(shellQuote(logURL.path)) 2>&1; printf %s $? > \(shellQuote(statusURL.path)) ) & printf %s $! > \(shellQuote(pidURL.path))",
        ]
            .compactMap { $0 }
            .joined(separator: "; ")

        try runAppleScriptCommand(launchCommand)

        let timeoutAt = Date().addingTimeInterval(5)
        while Date() < timeoutAt {
            if let pidString = try? String(contentsOf: pidURL).trimmingCharacters(in: .whitespacesAndNewlines),
               let pid = Int32(pidString) {
                let context = RunningContext(
                    scriptID: script.id,
                    startedAt: startedAt,
                    logURL: logURL,
                    kind: .privileged(pid: pid, statusURL: statusURL),
                    outputHandle: nil
                )
                return (context, pid)
            }
            Thread.sleep(forTimeInterval: 0.1)
        }

        throw ScriptProcessRunnerError.launchFailed("Privileged script launch did not return a process ID.")
    }

    private static func runAppleScriptCommand(_ shellCommand: String) throws {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "do shell script \"\(appleScriptQuote(shellCommand))\" with administrator privileges"]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ScriptProcessRunnerError.launchFailed(message?.isEmpty == false ? message! : "Privileged script launch failed.")
        }
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func appleScriptQuote(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func isProcessRunning(pid: Int32) -> Bool {
        guard pid > 0 else {
            return false
        }
        return kill(pid, 0) == 0
    }
}
