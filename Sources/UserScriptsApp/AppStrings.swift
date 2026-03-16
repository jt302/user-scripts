import Foundation
import UserScriptsCore

struct AppStrings {
    enum Language {
        case english
        case chinese
    }

    let language: Language

    init(language: Language) {
        self.language = language
    }

    init(
        preference: AppLanguagePreference,
        preferredLanguages: [String] = Locale.preferredLanguages,
        locale: Locale = .current
    ) {
        switch preference {
        case .english:
            self.language = .english
        case .chinese:
            self.language = .chinese
        case .system:
            let identifier = preferredLanguages.first?.lowercased() ?? locale.identifier.lowercased()
            self.language = identifier.hasPrefix("zh") ? .chinese : .english
        }
    }

    var appName: String { localized("UserScripts", "UserScripts") }
    var consoleTitle: String { localized("Console", "控制台") }
    var settingsTitle: String { localized("Settings", "设置") }
    var statusReady: String { localized("Ready", "就绪") }
    var statusAttention: String { localized("Attention", "注意") }
    var statusRunning: String { localized("Running", "运行中") }
    var statusScheduled: String { localized("Scheduled", "已计划") }
    var noScriptsYet: String { localized("No scripts yet", "还没有脚本") }
    var newScript: String { localized("New Script", "新建脚本") }
    var openConsole: String { localized("Open Console", "打开控制台") }
    var quit: String { localized("Quit", "退出") }
    var importTitle: String { localized("Import", "导入") }
    var exportTitle: String { localized("Export", "导出") }
    var settingsButton: String { localized("Settings", "设置") }
    var showAll: String { localized("Show All", "显示全部") }
    var noMatches: String { localized("No Matches", "没有匹配项") }
    var buildFirstScript: String { localized("Build Your First Script", "创建第一个脚本") }
    var searchScriptsPlaceholder: String { localized("Search scripts or commands", "搜索脚本或命令") }
    var selectScript: String { localized("Select A Script", "选择一个脚本") }
    var createScript: String { localized("Create Script", "创建脚本") }
    var editScript: String { localized("Edit Script", "编辑脚本") }
    var cancel: String { localized("Cancel", "取消") }
    var save: String { localized("Save", "保存") }
    var validationSummary: String { localized("Validation Summary", "校验摘要") }
    var commandTitle: String { localized("Command", "命令") }
    var environmentTitle: String { localized("Environment", "环境变量") }
    var environmentVariablesTitle: String { localized("Environment Variables", "环境变量") }
    var activityTitle: String { localized("Activity", "活动") }
    var latestLog: String { localized("Latest Log", "最近日志") }
    var runHistory: String { localized("Run History", "运行历史") }
    var noRunHistory: String { localized("No run history in this session yet.", "当前会话还没有运行历史。") }
    var executionTitle: String { localized("Execution", "执行") }
    var scheduleTitle: String { localized("Schedule", "计划") }
    var notificationsTitle: String { localized("Notifications", "通知") }
    var duplicate: String { localized("Duplicate", "复制") }
    var openLogs: String { localized("Open Logs", "打开日志") }
    var delete: String { localized("Delete", "删除") }
    var edit: String { localized("Edit", "编辑") }
    var start: String { localized("Start", "启动") }
    var stop: String { localized("Stop", "停止") }
    var launchAtLogin: String { localized("Launch at login", "登录时启动") }
    var openAppDataFolder: String { localized("Open App Data Folder", "打开数据目录") }
    var openLogsFolder: String { localized("Open Logs Folder", "打开日志目录") }
    var themeTitle: String { localized("Theme", "主题") }
    var languageTitle: String { localized("Language", "语言") }
    var closeBehaviorTitle: String { localized("Close Window", "关闭窗口") }
    var keepInMenuBar: String { localized("Keep in menu bar", "保留在菜单栏") }
    var quitApp: String { localized("Quit app", "退出应用") }
    var askEveryTime: String { localized("Ask every time", "每次询问") }
    var system: String { localized("System", "跟随系统") }
    var dark: String { localized("Dark", "暗色") }
    var light: String { localized("Light", "亮色") }
    var english: String { localized("English", "英文") }
    var chinese: String { localized("Chinese", "中文") }
    var basic: String { localized("Basic", "基础") }
    var runtime: String { localized("Runtime", "运行") }
    var manual: String { localized("Manual", "手动") }
    var interval: String { localized("Interval", "间隔") }
    var daily: String { localized("Daily", "每日") }
    var enabled: String { localized("Enabled", "启用") }
    var requiresPrivileges: String { localized("Requires Privileges", "需要权限") }
    var restoreOnAppLaunch: String { localized("Restore on App Launch", "应用启动时恢复") }
    var successNotification: String { localized("Success Notification", "成功通知") }
    var failureNotification: String { localized("Failure Notification", "失败通知") }
    var timeoutSeconds: String { localized("Timeout Seconds", "超时时间（秒）") }
    var shell: String { localized("Shell", "Shell") }
    var directory: String { localized("Directory", "目录") }
    var nextRun: String { localized("Next Run", "下次运行") }
    var privileges: String { localized("Privileges", "权限") }
    var restore: String { localized("Restore", "恢复") }
    var timeout: String { localized("Timeout", "超时") }
    var success: String { localized("Success", "成功") }
    var failure: String { localized("Failure", "失败") }
    var scriptsMetric: String { localized("Scripts", "脚本") }
    var runningMetric: String { localized("Running", "运行中") }
    var failedMetric: String { localized("Failed", "失败") }
    var userOnly: String { localized("User only", "仅当前用户") }
    var systemPrompt: String { localized("System prompt", "系统授权") }
    var off: String { localized("Off", "关闭") }
    var on: String { localized("On", "开启") }
    var notScheduled: String { localized("Not scheduled", "未计划") }
    var none: String { localized("None", "无") }
    var idleBadge: String { localized("IDLE", "空闲") }
    var runningBadge: String { localized("RUNNING", "运行中") }
    var failBadge: String { localized("FAIL", "失败") }
    var nextBadge: String { localized("NEXT", "下一次") }
    var offBadge: String { localized("OFF", "关闭") }
    var readyBadge: String { localized("READY", "就绪") }
    var successBadge: String { localized("SUCCESS", "成功") }

    func scriptsAvailable(_ count: Int) -> String {
        switch language {
        case .english:
            return "\(count) scripts available"
        case .chinese:
            return "共有 \(count) 个脚本"
        }
    }

    func failedScriptsNeedReview(_ count: Int) -> String {
        switch language {
        case .english:
            return "\(count) script failures need review"
        case .chinese:
            return "有 \(count) 个失败脚本需要处理"
        }
    }

    func runningScriptsActive(_ count: Int) -> String {
        switch language {
        case .english:
            return "\(count) scripts active now"
        case .chinese:
            return "当前有 \(count) 个脚本在运行"
        }
    }

    func scheduledScriptsQueued(_ count: Int) -> String {
        switch language {
        case .english:
            return "\(count) scripts queued"
        case .chinese:
            return "有 \(count) 个脚本已安排"
        }
    }

    func createFirstScriptBody() -> String {
        localized(
            "Create a command, give it a working directory, and run it from the menu bar or console.",
            "创建一个命令，设置工作目录，然后从菜单栏或控制台运行。"
        )
    }

    func noMatchBody() -> String {
        localized(
            "Try a different search term or switch filters to see more scripts.",
            "换一个搜索词或筛选条件以查看更多脚本。"
        )
    }

    func menuBarEmptyBody() -> String {
        localized(
            "Create your first script to start commands from the menu bar.",
            "创建第一个脚本后，就可以从菜单栏直接运行命令。"
        )
    }

    func selectScriptBody() -> String {
        localized(
            "Choose a script from the left to inspect its command, controls, schedule, and latest activity.",
            "从左侧选择脚本，查看命令、操作、计划和最近活动。"
        )
    }

    func createScriptBody() -> String {
        localized(
            "Turn any shell command into a one-click action with logs, scheduling, and menu bar controls.",
            "把任意 shell 命令变成可一键运行的动作，并附带日志、计划任务和菜单栏控制。"
        )
    }

    func editorSubtitle() -> String {
        localized(
            "Organize command, schedule, and runtime behavior in one focused editor.",
            "在一个聚焦的编辑器里管理命令、计划和运行行为。"
        )
    }

    func themeDescription() -> String {
        localized("Choose light, dark, or system appearance.", "选择亮色、暗色或跟随系统。")
    }

    func launchAtLoginDescription(isSupported: Bool) -> String {
        if isSupported {
            return localized(
                "Enable this to reopen UserScripts when you sign in.",
                "启用后，登录系统时会重新打开 UserScripts。"
            )
        }
        return localized(
            "Launch at login needs the app to run from a bundled .app build.",
            "登录时启动需要以打包后的 .app 形式运行。"
        )
    }

    func closeBehaviorDescription() -> String {
        localized(
            "Choose what happens when you close the console window.",
            "选择关闭控制台窗口时的行为。"
        )
    }

    func languageDescription() -> String {
        localized(
            "Switch all visible interface text immediately.",
            "立即切换界面可见文字。"
        )
    }

    func duplicatedScript(_ name: String) -> String {
        switch language {
        case .english:
            return "Duplicated \(name)."
        case .chinese:
            return "已复制 \(name)。"
        }
    }

    func validationIssues(_ messages: [String]) -> String {
        messages.joined(separator: "\n")
    }

    func scriptAlreadyRunning(_ name: String) -> String {
        switch language {
        case .english:
            return "\(name) is already running."
        case .chinese:
            return "\(name) 正在运行中。"
        }
    }

    func scriptStarted(_ name: String) -> String {
        switch language {
        case .english:
            return "\(name) started."
        case .chinese:
            return "\(name) 已启动。"
        }
    }

    func scriptScheduledStarted(_ name: String) -> String {
        switch language {
        case .english:
            return "\(name) started from schedule."
        case .chinese:
            return "\(name) 已按计划启动。"
        }
    }

    func scriptRestored(_ name: String) -> String {
        switch language {
        case .english:
            return "\(name) restored on launch."
        case .chinese:
            return "\(name) 已随应用启动恢复。"
        }
    }

    func scriptStartFailed(_ name: String, detail: String) -> String {
        switch language {
        case .english:
            return "\(name) failed to start: \(detail)"
        case .chinese:
            return "\(name) 启动失败：\(detail)"
        }
    }

    func scriptStopping(_ name: String) -> String {
        switch language {
        case .english:
            return "\(name) is stopping."
        case .chinese:
            return "\(name) 正在停止。"
        }
    }

    func scriptNotRunning(_ name: String) -> String {
        switch language {
        case .english:
            return "\(name) is not running."
        case .chinese:
            return "\(name) 当前未在运行。"
        }
    }

    func stopFailed(_ name: String, detail: String) -> String {
        switch language {
        case .english:
            return "\(name) failed to stop: \(detail)"
        case .chinese:
            return "\(name) 停止失败：\(detail)"
        }
    }

    func genericFailure(_ prefixEn: String, _ prefixZh: String, detail: String) -> String {
        switch language {
        case .english:
            return "\(prefixEn): \(detail)"
        case .chinese:
            return "\(prefixZh)：\(detail)"
        }
    }

    func exportSucceeded() -> String { localized("Exported script configuration.", "已导出脚本配置。") }
    func importSucceeded() -> String { localized("Imported script configuration.", "已导入脚本配置。") }
    func latestLogUnavailable() -> String { localized("No log output yet.", "暂无运行日志。") }
    func logUnreadable(_ path: String) -> String {
        switch language {
        case .english:
            return "Log file unavailable: \(path)"
        case .chinese:
            return "日志文件暂不可读：\(path)"
        }
    }

    func scriptFinished(_ name: String, exitCode: Int32, succeeded: Bool) -> String {
        switch language {
        case .english:
            return succeeded ? "\(name) completed." : "\(name) failed with exit \(exitCode)."
        case .chinese:
            return succeeded ? "\(name) 执行完成。" : "\(name) 执行失败，exit \(exitCode)。"
        }
    }

    func statusObserverFailed(_ name: String, detail: String) -> String {
        switch language {
        case .english:
            return "\(name) status observer failed: \(detail)"
        case .chinese:
            return "\(name) 状态监听失败：\(detail)"
        }
    }

    func successNotificationBody() -> String {
        localized("Script executed successfully.", "脚本执行成功。")
    }

    func failureNotificationBody(_ exitCode: Int32) -> String {
        switch language {
        case .english:
            return "Script failed with exit \(exitCode)."
        case .chinese:
            return "脚本执行失败，exit \(exitCode)。"
        }
    }

    func summaryReady(_ totalCount: Int) -> String {
        totalCount == 0 ? localized("Create your first script to get started", "创建第一个脚本即可开始") : scriptsAvailable(totalCount)
    }

    func filterTitle(_ filter: SidebarFilter) -> String {
        switch filter {
        case .all:
            localized("All", "全部")
        case .running:
            localized("Running", "运行中")
        case .scheduled:
            localized("Scheduled", "已计划")
        case .failed:
            localized("Failed", "失败")
        case .disabled:
            localized("Disabled", "已禁用")
        }
    }

    func scriptStatusRunning(pid: Int32?) -> String {
        switch language {
        case .english:
            return pid.map { "Running now · PID \($0)" } ?? "Running now"
        case .chinese:
            return pid.map { "运行中 · PID \($0)" } ?? "运行中"
        }
    }

    func scriptStatusFailed(exitCode: Int32) -> String {
        switch language {
        case .english:
            return "Last run failed · exit \(exitCode)"
        case .chinese:
            return "最近失败 · exit \(exitCode)"
        }
    }

    func scriptStatusScheduled(_ text: String) -> String {
        switch language {
        case .english:
            return "Next run · \(text)"
        case .chinese:
            return "下次运行 · \(text)"
        }
    }

    func scriptStatusDisabled() -> String {
        localized("Disabled", "已禁用")
    }

    func scriptStatusSucceeded(_ text: String) -> String {
        switch language {
        case .english:
            return "Last run succeeded · \(text)"
        case .chinese:
            return "最近成功 · \(text)"
        }
    }

    func scriptStatusIdle() -> String {
        localized("Ready to run", "准备就绪")
    }

    func completedSuccessfully() -> String {
        localized("Completed successfully", "执行成功")
    }

    func exitCode(_ value: Int32) -> String {
        localized("Exit \(value)", "退出码 \(value)")
    }

    func scheduleDescription(_ rule: SchedulerRule) -> String {
        switch rule {
        case .disabled:
            return manual
        case let .interval(minutes):
            switch language {
            case .english:
                return "Every \(minutes) min"
            case .chinese:
                return "每 \(minutes) 分钟"
            }
        case let .daily(hour, minute):
            switch language {
            case .english:
                return String(format: "Daily %02d:%02d", hour, minute)
            case .chinese:
                return String(format: "每日 %02d:%02d", hour, minute)
            }
        }
    }

    func localized(_ english: String, _ chinese: String) -> String {
        switch language {
        case .english:
            english
        case .chinese:
            chinese
        }
    }
}
