import XCTest
@testable import UserScriptsApp
import UserScriptsCore

final class AppPresentationTests: XCTestCase {
    func testSidebarFilterReturnsOnlyFailedScriptsMatchingQuery() {
        let failed = makeScript(name: "Deploy API")
        let running = makeScript(name: "Backup DB")
        let idle = makeScript(name: "Clean Temp")

        let state = DashboardPresentation.build(
            scripts: [failed, running, idle],
            selectedScriptID: failed.id,
            runningHandles: [
                running.id: RunningScriptHandle(
                    scriptID: running.id,
                    pid: 88,
                    startedAt: Date(timeIntervalSince1970: 100),
                    logURL: URL(fileURLWithPath: "/tmp/running.log")
                )
            ],
            recentRuns: [
                failed.id: ScriptRunRecord(
                    scriptID: failed.id,
                    startedAt: Date(timeIntervalSince1970: 10),
                    endedAt: Date(timeIntervalSince1970: 20),
                    exitCode: 1,
                    terminationReason: .exit,
                    logURL: URL(fileURLWithPath: "/tmp/failed.log")
                )
            ],
            nextRunDates: [:],
            searchText: "deploy",
            filter: .failed,
            bannerMessage: nil,
            strings: AppStrings(language: .english)
        )

        XCTAssertEqual(state.sidebarItems.map(\.title), ["Deploy API"])
        XCTAssertEqual(state.summary.totalCount, 3)
        XCTAssertEqual(state.summary.failedCount, 1)
    }

    func testMenuBarPrioritizesRunningThenFailedThenRecent() {
        let running = makeScript(name: "A Running")
        let failed = makeScript(name: "B Failed")
        let recent = makeScript(name: "C Recent")
        let idle = makeScript(name: "D Idle")

        let state = DashboardPresentation.build(
            scripts: [idle, recent, failed, running],
            selectedScriptID: nil,
            runningHandles: [
                running.id: RunningScriptHandle(
                    scriptID: running.id,
                    pid: 12,
                    startedAt: Date(timeIntervalSince1970: 200),
                    logURL: URL(fileURLWithPath: "/tmp/running.log")
                )
            ],
            recentRuns: [
                failed.id: ScriptRunRecord(
                    scriptID: failed.id,
                    startedAt: Date(timeIntervalSince1970: 100),
                    endedAt: Date(timeIntervalSince1970: 150),
                    exitCode: 1,
                    terminationReason: .exit,
                    logURL: URL(fileURLWithPath: "/tmp/failed.log")
                ),
                recent.id: ScriptRunRecord(
                    scriptID: recent.id,
                    startedAt: Date(timeIntervalSince1970: 300),
                    endedAt: Date(timeIntervalSince1970: 350),
                    exitCode: 0,
                    terminationReason: .exit,
                    logURL: URL(fileURLWithPath: "/tmp/recent.log")
                )
            ],
            nextRunDates: [:],
            searchText: "",
            filter: .all,
            bannerMessage: "boom",
            strings: AppStrings(language: .english)
        )

        XCTAssertEqual(state.menuBarItems.prefix(3).map(\.title), ["A Running", "B Failed", "C Recent"])
        XCTAssertEqual(state.hero.statusLabel, "Attention")
        XCTAssertEqual(state.hero.accent, .danger)
        XCTAssertNotEqual(state.hero.subtitle, "boom")
    }

    func testSelectedScriptOverviewShowsScheduleAndLastExitCode() {
        let script = makeScript(
            name: "Nightly Sync",
            scheduleRule: .daily(hour: 2, minute: 15),
            requiresPrivileges: true,
            runAtLoginRestore: true
        )

        let state = DashboardPresentation.build(
            scripts: [script],
            selectedScriptID: script.id,
            runningHandles: [:],
            recentRuns: [
                script.id: ScriptRunRecord(
                    scriptID: script.id,
                    startedAt: Date(timeIntervalSince1970: 100),
                    endedAt: Date(timeIntervalSince1970: 130),
                    exitCode: 23,
                    terminationReason: .exit,
                    logURL: URL(fileURLWithPath: "/tmp/fail.log")
                )
            ],
            nextRunDates: [script.id: Date(timeIntervalSince1970: 400)],
            searchText: "",
            filter: .all,
            bannerMessage: nil,
            strings: AppStrings(language: .english)
        )

        XCTAssertEqual(state.selection?.title, "Nightly Sync")
        XCTAssertEqual(state.selection?.overviewRows.first(where: { $0.label == "Schedule" })?.value, "Daily 02:15")
        XCTAssertEqual(state.selection?.overviewRows.first(where: { $0.label == "Privileges" })?.value, "System prompt")
        XCTAssertEqual(state.selection?.historyBadge, "Exit 23")
    }

    private func makeScript(
        name: String,
        scheduleRule: SchedulerRule = .disabled,
        requiresPrivileges: Bool = false,
        runAtLoginRestore: Bool = false
    ) -> ScriptDefinition {
        ScriptDefinition(
            id: UUID(),
            name: name,
            workingDirectory: "/tmp",
            command: "echo \(name)",
            shell: .zsh,
            environmentVariables: [:],
            scheduleRule: scheduleRule,
            allowConcurrentRuns: false,
            timeoutSeconds: nil,
            runAtLoginRestore: runAtLoginRestore,
            requiresPrivileges: requiresPrivileges,
            successNotificationEnabled: false,
            failureNotificationEnabled: true,
            isEnabled: true
        )
    }
}
