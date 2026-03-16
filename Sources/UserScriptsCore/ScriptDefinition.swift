import Foundation

public enum ScriptShell: String, Codable, CaseIterable, Sendable {
    case sh
    case zsh
    case bash

    public var launchPath: String {
        switch self {
        case .sh:
            "/bin/sh"
        case .zsh:
            "/bin/zsh"
        case .bash:
            "/bin/bash"
        }
    }
}

public enum SchedulerRule: Codable, Equatable, Sendable {
    case disabled
    case interval(minutes: Int)
    case daily(hour: Int, minute: Int)
}

public struct ScriptDefinition: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var workingDirectory: String
    public var command: String
    public var shell: ScriptShell
    public var environmentVariables: [String: String]
    public var scheduleRule: SchedulerRule
    public var allowConcurrentRuns: Bool
    public var timeoutSeconds: Int?
    public var runAtLoginRestore: Bool
    public var requiresPrivileges: Bool
    public var successNotificationEnabled: Bool
    public var failureNotificationEnabled: Bool
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        workingDirectory: String,
        command: String,
        shell: ScriptShell = .zsh,
        environmentVariables: [String: String] = [:],
        scheduleRule: SchedulerRule = .disabled,
        allowConcurrentRuns: Bool = false,
        timeoutSeconds: Int? = nil,
        runAtLoginRestore: Bool = false,
        requiresPrivileges: Bool = false,
        successNotificationEnabled: Bool = true,
        failureNotificationEnabled: Bool = true,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.workingDirectory = workingDirectory
        self.command = command
        self.shell = shell
        self.environmentVariables = environmentVariables
        self.scheduleRule = scheduleRule
        self.allowConcurrentRuns = allowConcurrentRuns
        self.timeoutSeconds = timeoutSeconds
        self.runAtLoginRestore = runAtLoginRestore
        self.requiresPrivileges = requiresPrivileges
        self.successNotificationEnabled = successNotificationEnabled
        self.failureNotificationEnabled = failureNotificationEnabled
        self.isEnabled = isEnabled
    }
}
