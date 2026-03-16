import Foundation

public struct ValidationIssue: Equatable, Sendable {
    public var field: String
    public var message: String

    public init(field: String, message: String) {
        self.field = field
        self.message = message
    }
}

public enum ScriptValidator {
    public static func validate(_ script: ScriptDefinition) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        if script.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(ValidationIssue(field: "command", message: "Command cannot be empty."))
        }

        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: script.workingDirectory, isDirectory: &isDirectory) || !isDirectory.boolValue {
            issues.append(ValidationIssue(field: "workingDirectory", message: "Working directory does not exist."))
        }

        if let timeoutSeconds = script.timeoutSeconds, timeoutSeconds <= 0 {
            issues.append(ValidationIssue(field: "timeoutSeconds", message: "Timeout must be greater than zero."))
        }

        switch script.scheduleRule {
        case .disabled:
            break
        case let .interval(minutes):
            if minutes <= 0 {
                issues.append(ValidationIssue(field: "scheduleRule", message: "Interval must be greater than zero minutes."))
            }
        case let .daily(hour, minute):
            if !(0...23).contains(hour) || !(0...59).contains(minute) {
                issues.append(ValidationIssue(field: "scheduleRule", message: "Daily schedule time is invalid."))
            }
        }

        return issues
    }
}
