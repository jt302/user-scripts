import XCTest
@testable import UserScriptsCore

final class ScriptFoundationTests: XCTestCase {
    func testValidatorRejectsBlankCommandAndMissingDirectory() {
        let script = ScriptDefinition(
            name: "Bad Script",
            workingDirectory: "/path/that/does/not/exist",
            command: "   "
        )

        let issues = ScriptValidator.validate(script)

        XCTAssertEqual(
            issues,
            [
                ValidationIssue(field: "command", message: "Command cannot be empty."),
                ValidationIssue(field: "workingDirectory", message: "Working directory does not exist."),
            ]
        )
    }

    func testSchedulerCalculatesNextDailyRunOnSameDayWhenTimeHasNotPassed() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let start = Date(timeIntervalSince1970: 1_711_015_200) // 2024-03-21 10:00 UTC
        let next = SchedulerCalculator().nextRunDate(
            for: .daily(hour: 18, minute: 30),
            after: start,
            calendar: calendar
        )

        XCTAssertEqual(next, Date(timeIntervalSince1970: 1_711_045_800)) // 2024-03-21 18:30 UTC
    }

    func testStorePersistsAndReloadsScripts() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = ScriptStore(fileURL: directory.appendingPathComponent("scripts.json"))
        let script = ScriptDefinition(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            name: "List Files",
            workingDirectory: "/tmp",
            command: "ls -la",
            shell: .zsh,
            environmentVariables: ["FOO": "bar"],
            scheduleRule: .interval(minutes: 15),
            allowConcurrentRuns: false,
            timeoutSeconds: 30,
            runAtLoginRestore: true,
            requiresPrivileges: false,
            successNotificationEnabled: false,
            failureNotificationEnabled: true,
            isEnabled: true
        )

        try await store.save([script])
        let loaded = try await store.load()

        XCTAssertEqual(loaded, [script])
    }

    func testStoreLoadsFromPathContainingSpaces() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("User Scripts \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = ScriptStore(fileURL: directory.appendingPathComponent("scripts.json"))
        let script = ScriptDefinition(
            name: "Echo",
            workingDirectory: "/tmp",
            command: "echo spaced path"
        )

        try await store.save([script])
        let loaded = try await store.load()

        XCTAssertEqual(loaded, [script])
    }

    func testRunnerCapturesSuccessfulCommandOutput() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let script = ScriptDefinition(
            name: "Echo",
            workingDirectory: "/tmp",
            command: "printf 'hello from runner'"
        )
        let runner = ScriptProcessRunner()

        _ = try await runner.start(script, logDirectory: directory)
        let record = try await runner.waitForExit(of: script.id)
        let output = try String(contentsOf: record.logURL)

        XCTAssertTrue(record.succeeded)
        XCTAssertEqual(output, "hello from runner")
    }

    func testRunnerStopsLongRunningProcess() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let script = ScriptDefinition(
            name: "Long Run",
            workingDirectory: "/tmp",
            command: "sleep 30"
        )
        let runner = ScriptProcessRunner()

        _ = try await runner.start(script, logDirectory: directory)
        try await Task.sleep(for: .milliseconds(200))
        let stopped = try await runner.stop(scriptID: script.id)
        let record = try await runner.waitForExit(of: script.id)

        XCTAssertTrue(stopped)
        XCTAssertEqual(record.terminationReason, .stopped)
    }
}
