import AppKit
import Foundation
import OSLog
import SwiftUI
import UserScriptsCore

@MainActor
final class AppModel: ObservableObject {
    enum RunSource {
        case manual
        case scheduled
        case restored
    }

    enum OverallStatus {
        case idle
        case running
        case failed
    }

    @Published private(set) var scripts: [ScriptDefinition] = []
    @Published private(set) var runningHandles: [UUID: RunningScriptHandle] = [:]
    @Published private(set) var recentRuns: [UUID: ScriptRunRecord] = [:]
    @Published private(set) var runHistory: [UUID: [ScriptRunRecord]] = [:]
    @Published private(set) var nextRunDates: [UUID: Date] = [:]
    @Published var selectedScriptID: UUID?
    @Published var bannerMessage: String?
    @Published var launchAtLoginEnabled = false
    @Published var launchAtLoginSupported = false
    @Published var searchText = ""
    @Published var selectedFilter: SidebarFilter = .all
    @Published var themePreference: AppThemePreference
    @Published var languagePreference: AppLanguagePreference
    @Published var closeBehaviorPreference: AppCloseBehaviorPreference

    private let paths: AppPaths
    private let store: ScriptStore
    private let runner = ScriptProcessRunner()
    private let scheduler = SchedulerCalculator()
    private let launchAtLoginController = LaunchAtLoginController()
    private let notifications = NotificationController()
    private let logger = Logger(subsystem: "com.tt.userscripts", category: "AppModel")
    private var scheduleTasks: [UUID: Task<Void, Never>] = [:]
    private var completionTasks: [UUID: Task<Void, Never>] = [:]
    private var bannerClearTask: Task<Void, Never>?
    private var didBootstrap = false
    private let themePreferenceKey = "themePreference"
    private let languagePreferenceKey = "languagePreference"
    private let closeBehaviorPreferenceKey = "closeBehaviorPreference"

    init(paths: AppPaths = .default) {
        self.paths = paths
        self.store = ScriptStore(fileURL: paths.scriptsFileURL)
        let storedTheme = UserDefaults.standard.string(forKey: themePreferenceKey)
        self.themePreference = storedTheme.flatMap(AppThemePreference.init(rawValue:)) ?? .system
        let storedLanguage = UserDefaults.standard.string(forKey: languagePreferenceKey)
        self.languagePreference = storedLanguage.flatMap(AppLanguagePreference.init(rawValue:)) ?? .system
        let storedCloseBehavior = UserDefaults.standard.string(forKey: closeBehaviorPreferenceKey)
        self.closeBehaviorPreference = storedCloseBehavior.flatMap(AppCloseBehaviorPreference.init(rawValue:)) ?? .ask
        Task { [weak self] in
            await self?.bootstrap()
        }
    }

    var selectedScript: ScriptDefinition? {
        guard let selectedScriptID else { return nil }
        return scripts.first(where: { $0.id == selectedScriptID })
    }

    var dashboardState: DashboardPresentation.State {
        DashboardPresentation.build(
            scripts: scripts,
            selectedScriptID: selectedScriptID,
            runningHandles: runningHandles,
            recentRuns: recentRuns,
            nextRunDates: nextRunDates,
            searchText: searchText,
            filter: selectedFilter,
            bannerMessage: bannerMessage,
            strings: strings
        )
    }

    var overallStatus: OverallStatus {
        if !runningHandles.isEmpty {
            return .running
        }
        if recentRuns.values.contains(where: { !$0.succeeded }) {
            return .failed
        }
        return .idle
    }

    var preferredColorScheme: ColorScheme? {
        themePreference.colorScheme
    }

    var strings: AppStrings {
        AppStrings(preference: languagePreference)
    }

    func bootstrap() async {
        guard !didBootstrap else {
            return
        }
        didBootstrap = true

        do {
            try paths.prepare()
            logger.info("Prepared app directories at \(self.paths.applicationSupportDirectory.path, privacy: .public)")
        } catch {
            showBanner(strings.genericFailure("Initialization failed", "初始化目录失败", detail: error.localizedDescription), autoDismissAfter: 6)
            logger.error("Failed to prepare app directories: \(error.localizedDescription, privacy: .public)")
        }

        await notifications.prepare()
        launchAtLoginSupported = launchAtLoginController.isSupported
        launchAtLoginEnabled = launchAtLoginController.isEnabled
        await reload()
        await restoreLaunchScripts()
    }

    func reload() async {
        do {
            scripts = try await store.load()
            logger.info("Loaded \(self.scripts.count) scripts from store")
            if selectedScriptID == nil {
                selectedScriptID = scripts.first?.id
            }
            rebuildSchedules()
        } catch {
            showBanner(strings.genericFailure("Failed to load scripts", "加载脚本失败", detail: error.localizedDescription), autoDismissAfter: 6)
            logger.error("Failed to load scripts: \(error.localizedDescription, privacy: .public)")
        }
    }

    func save(script: ScriptDefinition) async {
        if let index = scripts.firstIndex(where: { $0.id == script.id }) {
            scripts[index] = script
        } else {
            scripts.append(script)
        }
        scripts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        selectedScriptID = script.id
        await persist()
    }

    func deleteSelectedScript() async {
        guard let currentSelection = selectedScriptID else { return }
        if let index = scripts.firstIndex(where: { $0.id == currentSelection }) {
            if runningHandles[currentSelection] != nil {
                _ = try? await runner.stop(scriptID: currentSelection)
            }
            scripts.remove(at: index)
            runningHandles.removeValue(forKey: currentSelection)
            recentRuns.removeValue(forKey: currentSelection)
            runHistory.removeValue(forKey: currentSelection)
            nextRunDates.removeValue(forKey: currentSelection)
            scheduleTasks[currentSelection]?.cancel()
            completionTasks[currentSelection]?.cancel()
            selectedScriptID = scripts.first?.id
            await persist()
        }
    }

    func duplicateSelectedScript() async {
        guard let script = selectedScript else { return }
        var duplicate = script
        duplicate.id = UUID()
        duplicate.name = "\(script.name) Copy"
        scripts.append(duplicate)
        scripts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        selectedScriptID = duplicate.id
        showBanner(strings.duplicatedScript(script.name))
        await persist()
    }

    func newScriptTemplate() -> ScriptDefinition {
        ScriptDefinition(
            name: "New Script",
            workingDirectory: NSHomeDirectory(),
            command: "echo hello",
            shell: .zsh,
            environmentVariables: [:],
            scheduleRule: .disabled,
            allowConcurrentRuns: false,
            timeoutSeconds: nil,
            runAtLoginRestore: false,
            requiresPrivileges: false,
            successNotificationEnabled: false,
            failureNotificationEnabled: true,
            isEnabled: true
        )
    }

    func startSelectedScript() async {
        guard let selectedScriptID else { return }
        await start(scriptID: selectedScriptID, source: .manual)
    }

    func stopSelectedScript() async {
        guard let selectedScriptID else { return }
        await stop(scriptID: selectedScriptID)
    }

    func start(scriptID: UUID, source: RunSource) async {
        guard let script = scripts.first(where: { $0.id == scriptID }) else {
            return
        }

        let issues = ScriptValidator.validate(script)
        guard issues.isEmpty else {
            showBanner(strings.validationIssues(issues.map(\.message)), autoDismissAfter: 6)
            return
        }

        if runningHandles[scriptID] != nil {
            showBanner(strings.scriptAlreadyRunning(script.name))
            return
        }

        do {
            logger.info("Starting script \(script.name, privacy: .public) from source \(String(describing: source), privacy: .public)")
            let handle = try await runner.start(script, logDirectory: paths.logsDirectory)
            runningHandles[scriptID] = handle
            switch source {
            case .manual:
                showBanner(strings.scriptStarted(script.name))
            case .scheduled:
                showBanner(strings.scriptScheduledStarted(script.name))
            case .restored:
                showBanner(strings.scriptRestored(script.name))
            }
            observeCompletion(of: script)
        } catch {
            let nsError = error as NSError
            showBanner(strings.scriptStartFailed(script.name, detail: "\(nsError.localizedDescription) [\(nsError.domain)#\(nsError.code)]"), autoDismissAfter: 6)
            logger.error("Failed to start script \(script.name, privacy: .public): \(nsError.localizedDescription, privacy: .public) [\(nsError.domain, privacy: .public)#\(nsError.code)]")
        }
    }

    func stop(scriptID: UUID) async {
        guard let script = scripts.first(where: { $0.id == scriptID }) else {
            return
        }

        do {
            let stopped = try await runner.stop(scriptID: scriptID)
            showBanner(stopped ? strings.scriptStopping(script.name) : strings.scriptNotRunning(script.name))
            logger.info("Stop requested for \(script.name, privacy: .public), stopped=\(stopped)")
        } catch {
            showBanner(strings.stopFailed(script.name, detail: error.localizedDescription), autoDismissAfter: 6)
            logger.error("Failed to stop script \(script.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginController.setEnabled(enabled)
            launchAtLoginEnabled = enabled
            logger.info("Launch at login set to \(enabled)")
        } catch {
            launchAtLoginEnabled = launchAtLoginController.isEnabled
            showBanner(strings.genericFailure("Launch at login failed", "登录启动设置失败", detail: error.localizedDescription), autoDismissAfter: 6)
            logger.error("Failed to set launch at login: \(error.localizedDescription, privacy: .public)")
        }
    }

    func setThemePreference(_ preference: AppThemePreference) {
        themePreference = preference
        UserDefaults.standard.set(preference.rawValue, forKey: themePreferenceKey)
        logger.info("Theme preference changed to \(preference.rawValue, privacy: .public)")
    }

    func setLanguagePreference(_ preference: AppLanguagePreference) {
        languagePreference = preference
        UserDefaults.standard.set(preference.rawValue, forKey: languagePreferenceKey)
        logger.info("Language preference changed to \(preference.rawValue, privacy: .public)")
    }

    func setCloseBehaviorPreference(_ preference: AppCloseBehaviorPreference) {
        closeBehaviorPreference = preference
        UserDefaults.standard.set(preference.rawValue, forKey: closeBehaviorPreferenceKey)
        logger.info("Close behavior preference changed to \(preference.rawValue, privacy: .public)")
    }

    func latestLogText(for scriptID: UUID) -> String {
        guard let record = recentRuns[scriptID] else {
            return strings.latestLogUnavailable()
        }
        return (try? String(contentsOf: record.logURL)) ?? strings.logUnreadable(record.logURL.path)
    }

    func runHistory(for scriptID: UUID) -> [ScriptRunRecord] {
        runHistory[scriptID] ?? []
    }

    func logText(for record: ScriptRunRecord) -> String {
        (try? String(contentsOf: record.logURL)) ?? strings.logUnreadable(record.logURL.path)
    }

    func openLogsFolder() {
        NSWorkspace.shared.open(paths.logsDirectory)
    }

    func openDataFolder() {
        NSWorkspace.shared.open(paths.applicationSupportDirectory)
    }

    func exportScripts() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "user-scripts-export.json"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(scripts)
                try data.write(to: url, options: .atomic)
                showBanner(strings.exportSucceeded())
            } catch {
                showBanner(strings.genericFailure("Export failed", "导出失败", detail: error.localizedDescription), autoDismissAfter: 6)
            }
        }
    }

    func importScripts() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([ScriptDefinition].self, from: data)
                scripts = decoded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                selectedScriptID = scripts.first?.id
                showBanner(strings.importSucceeded())
                Task {
                    await persist()
                }
            } catch {
                showBanner(strings.genericFailure("Import failed", "导入失败", detail: error.localizedDescription), autoDismissAfter: 6)
            }
        }
    }

    func statusText(for script: ScriptDefinition) -> String {
        if let handle = runningHandles[script.id] {
            let pidText = handle.pid.map { "PID \($0)" } ?? "等待 PID"
            return "运行中 · \(pidText)"
        }
        if let nextRun = nextRunDates[script.id] {
            return "待执行 · \(nextRun.formatted(date: .abbreviated, time: .shortened))"
        }
        if let run = recentRuns[script.id] {
            return run.succeeded
                ? "最近成功 · \(run.endedAt.formatted(date: .abbreviated, time: .shortened))"
                : "最近失败 · exit \(run.exitCode)"
        }
        return script.isEnabled ? "空闲" : "已禁用"
    }

    func symbolName(for script: ScriptDefinition) -> String {
        if runningHandles[script.id] != nil {
            return "play.circle.fill"
        }
        if let run = recentRuns[script.id], !run.succeeded {
            return "exclamationmark.triangle.fill"
        }
        if nextRunDates[script.id] != nil {
            return "clock.fill"
        }
        return script.isEnabled ? "terminal" : "pause.circle"
    }

    func overallSymbolName() -> String {
        switch overallStatus {
        case .idle:
            return "terminal"
        case .running:
            return "terminal.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    func overallSummary() -> String {
        switch overallStatus {
        case .idle:
            return "当前空闲"
        case .running:
            return "运行中 \(runningHandles.count) 项"
        case .failed:
            return "有脚本最近运行失败"
        }
    }

    private func persist() async {
        do {
            try await store.save(scripts)
            rebuildSchedules()
        } catch {
            showBanner(strings.genericFailure("Save failed", "保存脚本失败", detail: error.localizedDescription), autoDismissAfter: 6)
        }
    }

    private func restoreLaunchScripts() async {
        for script in scripts where script.runAtLoginRestore && script.isEnabled {
            await start(scriptID: script.id, source: .restored)
        }
    }

    private func observeCompletion(of script: ScriptDefinition) {
        completionTasks[script.id]?.cancel()
        completionTasks[script.id] = Task { [weak self] in
            guard let self else { return }
            do {
                let record = try await runner.waitForExit(of: script.id)
                await MainActor.run {
                    runningHandles.removeValue(forKey: script.id)
                    recentRuns[script.id] = record
                    runHistory[script.id, default: []].insert(record, at: 0)
                    runHistory[script.id] = Array(runHistory[script.id, default: []].prefix(12))
                    completionTasks.removeValue(forKey: script.id)
                    showBanner(strings.scriptFinished(script.name, exitCode: record.exitCode, succeeded: record.succeeded))
                }
                logger.info("Script \(script.name, privacy: .public) finished with exitCode=\(record.exitCode) reason=\(record.terminationReason.rawValue, privacy: .public)")
                if record.succeeded, script.successNotificationEnabled {
                    await notifications.send(title: script.name, body: strings.successNotificationBody())
                }
                if !record.succeeded, script.failureNotificationEnabled {
                    await notifications.send(title: script.name, body: strings.failureNotificationBody(record.exitCode))
                }
            } catch {
                await MainActor.run {
                    runningHandles.removeValue(forKey: script.id)
                    completionTasks.removeValue(forKey: script.id)
                    showBanner(strings.statusObserverFailed(script.name, detail: error.localizedDescription), autoDismissAfter: 6)
                }
                logger.error("Completion observer failed for \(script.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    @discardableResult
    func handleConsoleWindowCloseRequest(window: NSWindow?) -> Bool {
        switch resolveCloseBehaviorDecision() {
        case .keepInMenuBar:
            window?.orderOut(nil)
            moveAppToMenuBar()
            return false
        case .terminate:
            NSApplication.shared.terminate(nil)
            return false
        case .cancel:
            return false
        }
    }

    func handleAppTerminationRequest(allWindows: [NSWindow]) -> NSApplication.TerminateReply {
        switch resolveCloseBehaviorDecision() {
        case .keepInMenuBar:
            allWindows.forEach { $0.orderOut(nil) }
            moveAppToMenuBar()
            return .terminateCancel
        case .terminate:
            return .terminateNow
        case .cancel:
            return .terminateCancel
        }
    }

    @discardableResult
    func handleQuitCommand(allWindows: [NSWindow]) -> Bool {
        switch resolveCloseBehaviorDecision() {
        case .keepInMenuBar:
            allWindows.forEach { $0.orderOut(nil) }
            moveAppToMenuBar()
            return false
        case .terminate:
            NSApplication.shared.terminate(nil)
            return true
        case .cancel:
            return false
        }
    }

    private func resolveCloseBehaviorDecision() -> CloseBehaviorDecision {
        switch closeBehaviorPreference {
        case .keepInMenuBar:
            return .keepInMenuBar
        case .quit:
            return .terminate
        case .ask:
            NSApplication.shared.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = strings.localized("When closing the console", "关闭控制台时")
            alert.informativeText = strings.localized(
                "Do you want to keep UserScripts running in the menu bar or quit the app?",
                "你希望仅关闭窗口并保留菜单栏运行，还是直接退出应用？"
            )
            alert.addButton(withTitle: strings.keepInMenuBar)
            alert.addButton(withTitle: strings.quitApp)
            alert.addButton(withTitle: strings.cancel)
            let rememberButton = NSButton(checkboxWithTitle: strings.localized("Remember my choice", "记住我的选择"), target: nil, action: nil)
            alert.accessoryView = rememberButton
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if rememberButton.state == .on {
                    setCloseBehaviorPreference(.keepInMenuBar)
                }
                return .keepInMenuBar
            }
            if response == .alertSecondButtonReturn {
                if rememberButton.state == .on {
                    setCloseBehaviorPreference(.quit)
                }
                return .terminate
            }
            return .cancel
        }
    }

    private func showBanner(_ message: String, autoDismissAfter seconds: Double = 4) {
        bannerClearTask?.cancel()
        withAnimation(.easeInOut(duration: 0.22)) {
            bannerMessage = message
        }
        bannerClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                self?.bannerMessage = nil
            }
        }
    }

    private func moveAppToMenuBar() {
        let processInfo = ProcessInfo.processInfo
        if processInfo.environment["XCTestConfigurationFilePath"] != nil
            || processInfo.processName.lowercased().contains("xctest")
            || processInfo.arguments.contains(where: { $0.lowercased().contains("xctest") }) {
            return
        }
        NSApp.keyWindow?.resignKey()
        NSApp.mainWindow?.resignMain()
        NSApp.hide(nil)
    }

    private func rebuildSchedules() {
        scheduleTasks.values.forEach { $0.cancel() }
        scheduleTasks.removeAll()
        nextRunDates.removeAll()

        for script in scripts where script.isEnabled {
            switch script.scheduleRule {
            case .disabled:
                continue
            default:
                scheduleTasks[script.id] = Task { [weak self] in
                    await self?.scheduleLoop(for: script.id)
                }
            }
        }
    }

    private func scheduleLoop(for scriptID: UUID) async {
        while !Task.isCancelled {
            guard let script = scripts.first(where: { $0.id == scriptID }), script.isEnabled else {
                _ = await MainActor.run {
                    nextRunDates.removeValue(forKey: scriptID)
                }
                return
            }

            guard let nextRun = scheduler.nextRunDate(for: script.scheduleRule, after: Date(), calendar: .current) else {
                _ = await MainActor.run {
                    nextRunDates.removeValue(forKey: scriptID)
                }
                return
            }

            await MainActor.run {
                nextRunDates[scriptID] = nextRun
            }

            let delay = max(nextRun.timeIntervalSinceNow, 0.2)
            try? await Task.sleep(for: .milliseconds(Int(delay * 1_000)))
            if Task.isCancelled {
                return
            }
            await start(scriptID: scriptID, source: .scheduled)
        }
    }

    private enum CloseBehaviorDecision {
        case keepInMenuBar
        case terminate
        case cancel
    }
}
