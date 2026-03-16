import Foundation
import UserScriptsCore

enum SidebarFilter: String, CaseIterable, Identifiable {
    case all
    case running
    case scheduled
    case failed
    case disabled

    var id: String { rawValue }
}

enum DashboardAccent: Equatable {
    case neutral
    case running
    case warning
    case danger
    case success
}

enum DashboardPresentation {
    struct State: Equatable {
        var summary: Summary
        var hero: Hero
        var sidebarItems: [SidebarItem]
        var menuBarItems: [MenuBarItem]
        var selection: Selection?
    }

    struct Summary: Equatable {
        var totalCount: Int
        var runningCount: Int
        var scheduledCount: Int
        var failedCount: Int
    }

    struct Hero: Equatable {
        var title: String
        var statusLabel: String
        var subtitle: String
        var accent: DashboardAccent
    }

    struct SidebarItem: Identifiable, Equatable {
        var id: UUID
        var title: String
        var subtitle: String
        var badge: String?
        var accent: DashboardAccent
        var isSelected: Bool
    }

    struct MenuBarItem: Identifiable, Equatable {
        var id: UUID
        var title: String
        var subtitle: String
        var accent: DashboardAccent
    }

    struct Selection: Equatable {
        struct OverviewRow: Equatable {
            var label: String
            var value: String
        }

        var title: String
        var subtitle: String
        var statusLabel: String
        var accent: DashboardAccent
        var historyBadge: String?
        var overviewRows: [OverviewRow]
        var commandText: String
        var environmentText: String
    }

    static func build(
        scripts: [ScriptDefinition],
        selectedScriptID: UUID?,
        runningHandles: [UUID: RunningScriptHandle],
        recentRuns: [UUID: ScriptRunRecord],
        nextRunDates: [UUID: Date],
        searchText: String,
        filter: SidebarFilter,
        bannerMessage: String?,
        strings: AppStrings
    ) -> State {
        let statuses = Dictionary(
            uniqueKeysWithValues: scripts.map {
                ($0.id, scriptStatus(for: $0, runningHandles: runningHandles, recentRuns: recentRuns, nextRunDates: nextRunDates, strings: strings))
            }
        )

        let summary = Summary(
            totalCount: scripts.count,
            runningCount: statuses.values.filter { $0.kind == .running }.count,
            scheduledCount: statuses.values.filter { $0.kind == .scheduled }.count,
            failedCount: statuses.values.filter { $0.kind == .failed }.count
        )

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filteredScripts = scripts
            .filter { script in
                let status = statuses[script.id]!
                let matchesFilter = switch filter {
                case .all:
                    true
                case .running:
                    status.kind == .running
                case .scheduled:
                    status.kind == .scheduled
                case .failed:
                    status.kind == .failed
                case .disabled:
                    status.kind == .disabled
                }

                guard matchesFilter else { return false }
                guard !query.isEmpty else { return true }
                return script.name.lowercased().contains(query)
                    || script.command.lowercased().contains(query)
                    || script.workingDirectory.lowercased().contains(query)
            }
            .sorted { lhs, rhs in
                let left = statuses[lhs.id]!
                let right = statuses[rhs.id]!
                if left.priority != right.priority {
                    return left.priority < right.priority
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        let sidebarItems = filteredScripts.map { script in
            let status = statuses[script.id]!
            return SidebarItem(
                id: script.id,
                title: script.name,
                subtitle: status.subtitle,
                badge: status.badge,
                accent: status.accent,
                isSelected: script.id == selectedScriptID
            )
        }

        let menuBarItems = scripts
            .sorted { lhs, rhs in
                let left = statuses[lhs.id]!
                let right = statuses[rhs.id]!
                if left.menuPriority != right.menuPriority {
                    return left.menuPriority < right.menuPriority
                }
                if left.sortDate != right.sortDate {
                    return left.sortDate > right.sortDate
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            .prefix(5)
            .map { script in
                let status = statuses[script.id]!
                return MenuBarItem(id: script.id, title: script.name, subtitle: status.subtitle, accent: status.accent)
            }

        let hero = hero(summary: summary, bannerMessage: bannerMessage, strings: strings)
        let selection = selectedScriptID
            .flatMap { id in scripts.first(where: { $0.id == id }) }
            .map { script in
                selectionState(for: script, status: statuses[script.id]!, nextRunDates: nextRunDates, recentRuns: recentRuns, strings: strings)
            }

        return State(summary: summary, hero: hero, sidebarItems: sidebarItems, menuBarItems: Array(menuBarItems), selection: selection)
    }

    private static func hero(summary: Summary, bannerMessage: String?, strings: AppStrings) -> Hero {
        if bannerMessage != nil {
            return Hero(title: strings.consoleTitle, statusLabel: strings.statusAttention, subtitle: summarySubtitle(summary: summary, strings: strings), accent: .danger)
        }
        if summary.failedCount > 0 {
            return Hero(title: strings.consoleTitle, statusLabel: strings.statusAttention, subtitle: strings.failedScriptsNeedReview(summary.failedCount), accent: .danger)
        }
        if summary.runningCount > 0 {
            return Hero(title: strings.consoleTitle, statusLabel: strings.statusRunning, subtitle: strings.runningScriptsActive(summary.runningCount), accent: .running)
        }
        if summary.scheduledCount > 0 {
            return Hero(title: strings.consoleTitle, statusLabel: strings.statusScheduled, subtitle: strings.scheduledScriptsQueued(summary.scheduledCount), accent: .warning)
        }
        return Hero(title: strings.consoleTitle, statusLabel: strings.statusReady, subtitle: summarySubtitle(summary: summary, strings: strings), accent: .neutral)
    }

    private static func summarySubtitle(summary: Summary, strings: AppStrings) -> String {
        strings.summaryReady(summary.totalCount)
    }

    private static func selectionState(
        for script: ScriptDefinition,
        status: ScriptStatus,
        nextRunDates: [UUID: Date],
        recentRuns: [UUID: ScriptRunRecord],
        strings: AppStrings
    ) -> Selection {
        let timeoutValue = script.timeoutSeconds.map { "\($0)s" } ?? strings.none
        let envText = script.environmentVariables.isEmpty
            ? strings.localized("No custom environment", "没有自定义环境变量")
            : script.environmentVariables
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: "\n")
        let historyBadge = recentRuns[script.id].map { $0.succeeded ? strings.successBadge : strings.exitCode($0.exitCode) }
        let nextRunValue = nextRunDates[script.id]?.formatted(date: .abbreviated, time: .shortened) ?? strings.notScheduled

        return Selection(
            title: script.name,
            subtitle: status.subtitle,
            statusLabel: status.badge ?? strings.idleBadge,
            accent: status.accent,
            historyBadge: historyBadge,
            overviewRows: [
                .init(label: strings.shell, value: script.shell.rawValue),
                .init(label: strings.directory, value: script.workingDirectory),
                .init(label: strings.scheduleTitle, value: strings.scheduleDescription(script.scheduleRule)),
                .init(label: strings.nextRun, value: nextRunValue),
                .init(label: strings.privileges, value: script.requiresPrivileges ? strings.systemPrompt : strings.userOnly),
                .init(label: strings.restore, value: script.runAtLoginRestore ? strings.localized("On app launch", "应用启动时恢复") : strings.off),
                .init(label: strings.timeout, value: timeoutValue),
            ],
            commandText: script.command,
            environmentText: envText
        )
    }

    private static func scriptStatus(
        for script: ScriptDefinition,
        runningHandles: [UUID: RunningScriptHandle],
        recentRuns: [UUID: ScriptRunRecord],
        nextRunDates: [UUID: Date],
        strings: AppStrings
    ) -> ScriptStatus {
        if let handle = runningHandles[script.id] {
            return ScriptStatus(kind: .running, accent: .running, subtitle: strings.scriptStatusRunning(pid: handle.pid), badge: strings.runningBadge, priority: 0, menuPriority: 0, sortDate: handle.startedAt)
        }
        if let run = recentRuns[script.id], !run.succeeded {
            return ScriptStatus(kind: .failed, accent: .danger, subtitle: strings.scriptStatusFailed(exitCode: run.exitCode), badge: strings.failBadge, priority: 1, menuPriority: 1, sortDate: run.endedAt)
        }
        if let nextRun = nextRunDates[script.id] {
            return ScriptStatus(kind: .scheduled, accent: .warning, subtitle: strings.scriptStatusScheduled(nextRun.formatted(date: .abbreviated, time: .shortened)), badge: strings.nextBadge, priority: 2, menuPriority: 3, sortDate: nextRun)
        }
        if !script.isEnabled {
            return ScriptStatus(kind: .disabled, accent: .neutral, subtitle: strings.scriptStatusDisabled(), badge: strings.offBadge, priority: 4, menuPriority: 5, sortDate: .distantPast)
        }
        if let run = recentRuns[script.id] {
            return ScriptStatus(kind: .idle, accent: .neutral, subtitle: strings.scriptStatusSucceeded(run.endedAt.formatted(date: .abbreviated, time: .shortened)), badge: strings.readyBadge, priority: 3, menuPriority: 2, sortDate: run.endedAt)
        }
        return ScriptStatus(kind: .idle, accent: .neutral, subtitle: strings.scriptStatusIdle(), badge: strings.idleBadge, priority: 3, menuPriority: 4, sortDate: .distantPast)
    }

    private struct ScriptStatus {
        enum Kind {
            case running
            case failed
            case scheduled
            case idle
            case disabled
        }

        var kind: Kind
        var accent: DashboardAccent
        var subtitle: String
        var badge: String?
        var priority: Int
        var menuPriority: Int
        var sortDate: Date
    }
}
