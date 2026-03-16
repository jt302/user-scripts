import AppKit
import SwiftUI
import UserScriptsCore

struct ManagerRootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScriptConsoleView()
            .environmentObject(model)
            .preferredColorScheme(model.preferredColorScheme)
            .background(DashboardTheme.window)
            .frame(minWidth: 1120, minHeight: 720)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                WindowAccessor { window in
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.registerConsoleWindow(window, model: model)
                    }
                }
            )
    }
}

private struct ScriptConsoleView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editorDraft: ScriptDefinition?
    @State private var activityTab: ActivityTab = .latestLog
    @State private var selectedHistoryRecordID: UUID?

    private var strings: AppStrings { model.strings }

    var body: some View {
        let state = model.dashboardState

        HSplitView {
            sidebar(state: state)
                .frame(minWidth: 310, idealWidth: 340, maxWidth: 360)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(DashboardTheme.sidebar)

            detail(state: state)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(DashboardTheme.window)
        }
        .background(DashboardTheme.window)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $editorDraft) { draft in
            ScriptEditorSheet(initialScript: draft, strings: strings) { saved in
                Task { await model.save(script: saved) }
            }
            .preferredColorScheme(model.preferredColorScheme)
        }
        .animation(.easeInOut(duration: 0.18), value: model.selectedScriptID)
        .animation(.easeInOut(duration: 0.18), value: model.searchText)
        .animation(.easeInOut(duration: 0.18), value: model.selectedFilter)
    }

    private func sidebar(state: DashboardPresentation.State) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(strings.appName)
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(DashboardTheme.textPrimary)
                        Text(state.hero.subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DashboardTheme.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    statusPill(label: state.hero.statusLabel, accent: state.hero.accent)
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(DashboardTheme.textMuted)
                    TextField(strings.searchScriptsPlaceholder, text: $model.searchText)
                        .textFieldStyle(.plain)
                        .foregroundStyle(DashboardTheme.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(DashboardTheme.panelRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DashboardTheme.stroke, lineWidth: 1)
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SidebarFilter.allCases) { filter in
                            Button(strings.filterTitle(filter)) {
                                model.selectedFilter = filter
                            }
                            .buttonStyle(FilterChipButtonStyle(isActive: model.selectedFilter == filter))
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)

            Group {
                if state.sidebarItems.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(model.scripts.isEmpty ? strings.buildFirstScript : strings.noMatches)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DashboardTheme.textPrimary)
                        Text(model.scripts.isEmpty ? strings.createFirstScriptBody() : strings.noMatchBody())
                            .font(.system(size: 13))
                            .foregroundStyle(DashboardTheme.textSecondary)
                        Button(model.scripts.isEmpty ? strings.newScript : strings.showAll) {
                            if model.scripts.isEmpty {
                                editorDraft = model.newScriptTemplate()
                            } else {
                                model.searchText = ""
                                model.selectedFilter = .all
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle(accent: .running))
                    }
                    .dashboardCard()
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(state.sidebarItems) { item in
                                SidebarScriptRow(item: item)
                                    .onTapGesture {
                                        model.selectedScriptID = item.id
                                        selectedHistoryRecordID = nil
                                        activityTab = .latestLog
                                    }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            VStack(spacing: 10) {
                Button {
                    editorDraft = model.newScriptTemplate()
                } label: {
                    Label(strings.newScript, systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle(accent: .running))

                HStack(spacing: 10) {
                    Button(strings.importTitle) { model.importScripts() }
                        .buttonStyle(SecondaryActionButtonStyle())
                    Button(strings.exportTitle) { model.exportScripts() }
                        .buttonStyle(SecondaryActionButtonStyle())
                    SettingsLink {
                        Image(systemName: "gearshape")
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(IconActionButtonStyle())
                    .help(strings.settingsButton)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func detail(state: DashboardPresentation.State) -> some View {
        Group {
            if let selection = state.selection, let script = model.selectedScript {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if let bannerMessage = model.bannerMessage {
                            BannerStrip(message: bannerMessage, accent: state.hero.accent)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        header(selection: selection, script: script, summary: state.summary)
                        overviewGrid(selection: selection, script: script)
                        contentGrid(selection: selection)
                        activityPanel(script: script)
                    }
                    .padding(24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .animation(.easeInOut(duration: 0.22), value: model.bannerMessage)
            } else {
                ConsoleEmptyStateView(
                    title: model.scripts.isEmpty ? strings.buildFirstScript : strings.selectScript,
                    bodyText: model.scripts.isEmpty ? strings.createScriptBody() : strings.selectScriptBody(),
                    buttonTitle: model.scripts.isEmpty ? strings.createScript : nil
                ) {
                    editorDraft = model.newScriptTemplate()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.22), value: model.bannerMessage)
    }

    private func header(selection: DashboardPresentation.Selection, script: ScriptDefinition, summary: DashboardPresentation.Summary) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(selection.accent.color)
                        .frame(width: 10, height: 10)
                    Text(selection.title)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(DashboardTheme.textPrimary)
                    statusPill(label: selection.statusLabel, accent: selection.accent)
                    if let historyBadge = selection.historyBadge {
                        subtlePill(label: historyBadge)
                    }
                }
                Text(selection.subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.textSecondary)

                HStack(spacing: 12) {
                    metricCard(title: strings.scriptsMetric, value: "\(summary.totalCount)", accent: .neutral)
                    metricCard(title: strings.runningMetric, value: "\(summary.runningCount)", accent: .running)
                    metricCard(title: strings.failedMetric, value: "\(summary.failedCount)", accent: .danger)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 10) {
                    if model.runningHandles[script.id] != nil {
                        Button(strings.stop) { Task { await model.stop(scriptID: script.id) } }
                            .buttonStyle(PrimaryActionButtonStyle(accent: .danger))
                    } else {
                        Button(strings.start) { Task { await model.start(scriptID: script.id, source: .manual) } }
                            .buttonStyle(PrimaryActionButtonStyle(accent: .running))
                    }

                    Button(strings.edit) {
                        editorDraft = script
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }

                HStack(spacing: 10) {
                    Button(strings.duplicate) { Task { await model.duplicateSelectedScript() } }
                        .buttonStyle(SecondaryActionButtonStyle())
                    Button(strings.openLogs) { model.openLogsFolder() }
                        .buttonStyle(SecondaryActionButtonStyle())
                    Button(strings.delete) { Task { await model.deleteSelectedScript() } }
                        .buttonStyle(DestructiveActionButtonStyle())
                }
            }
        }
        .dashboardCard()
    }

    private func overviewGrid(selection: DashboardPresentation.Selection, script: ScriptDefinition) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
            ],
            spacing: 16
        ) {
            OverviewCard(
                title: strings.executionTitle,
                accent: selection.accent,
                rows: selection.overviewRows.filter { [strings.shell, strings.directory, strings.timeout].contains($0.label) }
            )
            OverviewCard(
                title: strings.scheduleTitle,
                accent: .warning,
                rows: selection.overviewRows.filter { [strings.scheduleTitle, strings.nextRun, strings.restore].contains($0.label) }
            )
            OverviewCard(
                title: strings.notificationsTitle,
                accent: .neutral,
                rows: [
                    .init(label: strings.success, value: script.successNotificationEnabled ? strings.on : strings.off),
                    .init(label: strings.failure, value: script.failureNotificationEnabled ? strings.on : strings.off),
                    .init(label: strings.privileges, value: selection.overviewRows.first(where: { $0.label == strings.privileges })?.value ?? strings.userOnly),
                ]
            )
        }
    }

    private func contentGrid(selection: DashboardPresentation.Selection) -> some View {
        HStack(alignment: .top, spacing: 16) {
            codePanel(title: strings.commandTitle, value: selection.commandText)
            codePanel(title: strings.environmentTitle, value: selection.environmentText)
        }
    }

    private func codePanel(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DashboardTheme.textSecondary)
            Text(value)
                .textSelection(.enabled)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(DashboardTheme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        }
        .dashboardCard()
        .frame(maxWidth: .infinity)
    }

    private func activityPanel(script: ScriptDefinition) -> some View {
        let history = model.runHistory(for: script.id)
        let selectedHistoryRecord = history.first(where: { $0.id == selectedHistoryRecordID }) ?? history.first

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(strings.activityTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DashboardTheme.textPrimary)
                Spacer()
                Picker("Activity", selection: $activityTab) {
                    ForEach(ActivityTab.allCases, id: \.self) { tab in
                        Text(tab.title(using: strings)).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }

            if activityTab == .latestLog {
                ScrollView {
                    Text(model.latestLogText(for: script.id))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(DashboardTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 280)
            } else if history.isEmpty {
                Text(strings.noRunHistory)
                    .font(.system(size: 13))
                    .foregroundStyle(DashboardTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
            } else {
                VStack(spacing: 14) {
                    ForEach(history) { record in
                        Button {
                            selectedHistoryRecordID = record.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.endedAt.formatted(date: .abbreviated, time: .shortened))
                                        .foregroundStyle(DashboardTheme.textPrimary)
                                    Text(record.succeeded ? strings.completedSuccessfully() : strings.exitCode(record.exitCode))
                                        .foregroundStyle(DashboardTheme.textSecondary)
                                        .font(.system(size: 12))
                                }
                                Spacer()
                                subtlePill(label: record.succeeded ? strings.successBadge : strings.failBadge)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(selectedHistoryRecord?.id == record.id ? DashboardTheme.panelRaised : DashboardTheme.window.opacity(0.4))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if let selectedHistoryRecord {
                        Divider().overlay(DashboardTheme.stroke)
                        ScrollView {
                            Text(model.logText(for: selectedHistoryRecord))
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(DashboardTheme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .textSelection(.enabled)
                        }
                        .frame(minHeight: 200)
                    }
                }
            }
        }
        .dashboardCard()
    }

    private func metricCard(title: String, value: String, accent: DashboardAccent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DashboardTheme.textMuted)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(accent == .neutral ? DashboardTheme.textPrimary : accent.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DashboardTheme.panelRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DashboardTheme.stroke, lineWidth: 1)
        )
    }
}

private struct SidebarScriptRow: View {
    let item: DashboardPresentation.SidebarItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(item.accent.color)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .foregroundStyle(DashboardTheme.textPrimary)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(item.subtitle)
                    .foregroundStyle(DashboardTheme.textSecondary)
                    .font(.system(size: 12))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if let badge = item.badge {
                subtlePillStatic(label: badge, accent: item.accent)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(item.isSelected ? DashboardTheme.panelRaised : DashboardTheme.panel.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(item.isSelected ? item.accent.color.opacity(0.22) : DashboardTheme.stroke, lineWidth: 1)
        )
    }

    private func subtlePillStatic(label: String, accent: DashboardAccent) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(accent == .neutral ? DashboardTheme.textSecondary : accent.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(DashboardTheme.panelRaised, in: Capsule())
    }
}

private struct OverviewCard: View {
    let title: String
    let accent: DashboardAccent
    let rows: [DashboardPresentation.Selection.OverviewRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DashboardTheme.textPrimary)
                Spacer()
                Circle()
                    .fill(accent == .neutral ? DashboardTheme.textMuted : accent.color)
                    .frame(width: 7, height: 7)
            }
            ForEach(rows, id: \.label) { row in
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.label.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DashboardTheme.textMuted)
                    Text(row.value)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DashboardTheme.textPrimary)
                        .lineLimit(2)
                }
            }
        }
        .dashboardCard()
    }
}

struct BannerStrip: View {
    let message: String
    let accent: DashboardAccent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: accent == .danger ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundStyle(accent == .neutral ? DashboardTheme.textSecondary : accent.color)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DashboardTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(DashboardTheme.panelRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke((accent == .neutral ? DashboardTheme.stroke : accent.color.opacity(0.18)), lineWidth: 1)
        )
    }
}

private struct ConsoleEmptyStateView: View {
    let title: String
    let bodyText: String
    let buttonTitle: String?
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(DashboardTheme.textPrimary)
            Text(bodyText)
                .font(.system(size: 16))
                .foregroundStyle(DashboardTheme.textSecondary)
                .frame(maxWidth: 520, alignment: .leading)
            if let buttonTitle {
                Button(buttonTitle, action: onCreate)
                    .buttonStyle(PrimaryActionButtonStyle(accent: .running))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(60)
        .background(DashboardTheme.window)
    }
}

struct AppSettingsView: View {
    @EnvironmentObject private var model: AppModel

    private var strings: AppStrings { model.strings }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 0) {
                    settingsRow(
                        title: strings.themeTitle,
                        description: strings.themeDescription()
                    ) {
                        Picker("Theme", selection: Binding(
                            get: { model.themePreference },
                            set: { model.setThemePreference($0) }
                        )) {
                            ForEach(AppThemePreference.allCases) { preference in
                                Text(preference.title(using: strings)).tag(preference)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    settingsDivider

                    settingsRow(
                        title: strings.languageTitle,
                        description: strings.languageDescription()
                    ) {
                        Picker("Language", selection: Binding(
                            get: { model.languagePreference },
                            set: { model.setLanguagePreference($0) }
                        )) {
                            ForEach(AppLanguagePreference.allCases) { preference in
                                Text(preference.title(using: strings)).tag(preference)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    settingsDivider

                    settingsRow(
                        title: strings.closeBehaviorTitle,
                        description: strings.closeBehaviorDescription()
                    ) {
                        Picker("Close Behavior", selection: Binding(
                            get: { model.closeBehaviorPreference },
                            set: { model.setCloseBehaviorPreference($0) }
                        )) {
                            ForEach(AppCloseBehaviorPreference.allCases) { preference in
                                Text(preference.title(using: strings)).tag(preference)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    settingsDivider

                    settingsRow(
                        title: strings.launchAtLogin,
                        description: strings.launchAtLoginDescription(isSupported: model.launchAtLoginSupported)
                    ) {
                        Toggle("", isOn: Binding(
                            get: { model.launchAtLoginEnabled },
                            set: { model.toggleLaunchAtLogin($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(!model.launchAtLoginSupported)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .dashboardCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text(strings.localized("Storage", "存储"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DashboardTheme.textSecondary)

                    HStack(spacing: 12) {
                        Button(strings.openAppDataFolder) { model.openDataFolder() }
                            .buttonStyle(SecondaryActionButtonStyle())
                        Button(strings.openLogsFolder) { model.openLogsFolder() }
                            .buttonStyle(SecondaryActionButtonStyle())
                        Spacer(minLength: 0)
                    }
                }
                .dashboardCard()
            }
            .frame(maxWidth: 600, alignment: .topLeading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .preferredColorScheme(model.preferredColorScheme)
        .background(DashboardTheme.window)
        .frame(minWidth: 560, idealWidth: 580, maxWidth: 620, minHeight: 420)
        .background(
            WindowAccessor { window in
                switch model.preferredColorScheme {
                case .dark:
                    window.appearance = NSAppearance(named: .darkAqua)
                case .light:
                    window.appearance = NSAppearance(named: .aqua)
                case nil:
                    window.appearance = nil
                @unknown default:
                    window.appearance = nil
                }
            }
        )
    }

    private func settingsRow<Control: View>(
        title: String,
        description: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DashboardTheme.textPrimary)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            control()
                .frame(maxWidth: 540, alignment: .leading)
        }
        .padding(.vertical, 12)
    }

    private var settingsDivider: some View {
        Divider()
            .overlay(DashboardTheme.stroke)
    }
}

private struct ScriptEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var section: EditorSection = .basic
    @State private var name: String
    @State private var workingDirectory: String
    @State private var command: String
    @State private var shell: ScriptShell
    @State private var environmentText: String
    @State private var scheduleMode: ScheduleMode
    @State private var intervalMinutes: String
    @State private var dailyHour: String
    @State private var dailyMinute: String
    @State private var timeoutSeconds: String
    @State private var runAtLoginRestore: Bool
    @State private var requiresPrivileges: Bool
    @State private var successNotificationEnabled: Bool
    @State private var failureNotificationEnabled: Bool
    @State private var isEnabled: Bool

    private let initialScript: ScriptDefinition
    private let strings: AppStrings
    private let onSave: (ScriptDefinition) -> Void

    init(initialScript: ScriptDefinition, strings: AppStrings, onSave: @escaping (ScriptDefinition) -> Void) {
        self.initialScript = initialScript
        self.strings = strings
        self.onSave = onSave
        _name = State(initialValue: initialScript.name)
        _workingDirectory = State(initialValue: initialScript.workingDirectory)
        _command = State(initialValue: initialScript.command)
        _shell = State(initialValue: initialScript.shell)
        _environmentText = State(initialValue: initialScript.environmentVariables
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "\n"))
        _timeoutSeconds = State(initialValue: initialScript.timeoutSeconds.map(String.init) ?? "")
        _runAtLoginRestore = State(initialValue: initialScript.runAtLoginRestore)
        _requiresPrivileges = State(initialValue: initialScript.requiresPrivileges)
        _successNotificationEnabled = State(initialValue: initialScript.successNotificationEnabled)
        _failureNotificationEnabled = State(initialValue: initialScript.failureNotificationEnabled)
        _isEnabled = State(initialValue: initialScript.isEnabled)

        switch initialScript.scheduleRule {
        case .disabled:
            _scheduleMode = State(initialValue: .manual)
            _intervalMinutes = State(initialValue: "15")
            _dailyHour = State(initialValue: "09")
            _dailyMinute = State(initialValue: "00")
        case let .interval(minutes):
            _scheduleMode = State(initialValue: .interval)
            _intervalMinutes = State(initialValue: String(minutes))
            _dailyHour = State(initialValue: "09")
            _dailyMinute = State(initialValue: "00")
        case let .daily(hour, minute):
            _scheduleMode = State(initialValue: .daily)
            _intervalMinutes = State(initialValue: "15")
            _dailyHour = State(initialValue: String(format: "%02d", hour))
            _dailyMinute = State(initialValue: String(format: "%02d", minute))
        }
    }

    var body: some View {
        let draft = builtScript()
        let issues = ScriptValidator.validate(draft)

        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(initialScript.name == strings.newScript ? strings.createScript : strings.editScript)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(DashboardTheme.textPrimary)
                    Text(strings.editorSubtitle())
                        .font(.system(size: 13))
                        .foregroundStyle(DashboardTheme.textSecondary)
                }
                Spacer()
                Button(strings.cancel) { dismiss() }
                    .buttonStyle(SecondaryActionButtonStyle())
                Button(strings.save) {
                    onSave(draft)
                    dismiss()
                }
                .buttonStyle(PrimaryActionButtonStyle(accent: .running))
                .disabled(!issues.isEmpty)
            }

            if !issues.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(strings.validationSummary)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DashboardAccent.danger.color)
                    ForEach(issues, id: \.field) { issue in
                        Text(issue.message)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DashboardTheme.textPrimary)
                    }
                }
                .padding(14)
                .background(DashboardTheme.panelRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DashboardAccent.danger.color.opacity(0.2), lineWidth: 1)
                )
            }

            Picker("Section", selection: $section) {
                ForEach(EditorSection.allCases, id: \.self) { item in
                    Text(item.title(using: strings)).tag(item)
                }
            }
            .pickerStyle(.segmented)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch section {
                    case .basic:
                        editorCard(strings.basic) {
                            LabeledField(strings.localized("Name", "名称")) { TextField(strings.localized("Script name", "脚本名称"), text: $name) }
                            LabeledField(strings.localized("Working Directory", "工作目录")) { TextField("/path/to/project", text: $workingDirectory) }
                            LabeledField(strings.shell) {
                                Picker("Shell", selection: $shell) {
                                    ForEach(ScriptShell.allCases, id: \.self) { value in
                                        Text(value.rawValue).tag(value)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            Toggle(strings.enabled, isOn: $isEnabled)
                            Toggle(strings.restoreOnAppLaunch, isOn: $runAtLoginRestore)
                        }
                    case .command:
                        editorCard(strings.commandTitle) {
                            TextEditor(text: $command)
                                .font(.system(size: 13, design: .monospaced))
                                .frame(minHeight: 220)
                                .scrollContentBackground(.hidden)
                                .padding(12)
                                .background(DashboardTheme.window, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            Text(strings.environmentVariablesTitle)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DashboardTheme.textSecondary)
                            TextEditor(text: $environmentText)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(minHeight: 140)
                                .scrollContentBackground(.hidden)
                                .padding(12)
                                .background(DashboardTheme.window, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    case .schedule:
                        editorCard(strings.scheduleTitle) {
                            Picker("Mode", selection: $scheduleMode) {
                                ForEach(ScheduleMode.allCases, id: \.self) { mode in
                                    Text(mode.title(using: strings)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            if scheduleMode == .interval {
                                LabeledField(strings.localized("Interval Minutes", "间隔分钟")) { TextField("15", text: $intervalMinutes) }
                            }

                            if scheduleMode == .daily {
                                HStack(spacing: 12) {
                                    LabeledField(strings.localized("Hour", "小时")) { TextField("09", text: $dailyHour) }
                                    LabeledField(strings.localized("Minute", "分钟")) { TextField("00", text: $dailyMinute) }
                                }
                            }
                        }
                    case .runtime:
                        editorCard(strings.runtime) {
                            Toggle(strings.requiresPrivileges, isOn: $requiresPrivileges)
                            Toggle(strings.successNotification, isOn: $successNotificationEnabled)
                            Toggle(strings.failureNotification, isOn: $failureNotificationEnabled)
                            LabeledField(strings.timeoutSeconds) { TextField(strings.localized("Optional", "可选"), text: $timeoutSeconds) }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 680)
        .background(DashboardTheme.window)
    }

    private func editorCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DashboardTheme.textPrimary)
            content()
        }
        .dashboardCard()
    }

    private func builtScript() -> ScriptDefinition {
        ScriptDefinition(
            id: initialScript.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? strings.localized("Untitled Script", "未命名脚本") : name,
            workingDirectory: workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines),
            command: command,
            shell: shell,
            environmentVariables: parseEnvironment(),
            scheduleRule: buildSchedule(),
            allowConcurrentRuns: initialScript.allowConcurrentRuns,
            timeoutSeconds: Int(timeoutSeconds),
            runAtLoginRestore: runAtLoginRestore,
            requiresPrivileges: requiresPrivileges,
            successNotificationEnabled: successNotificationEnabled,
            failureNotificationEnabled: failureNotificationEnabled,
            isEnabled: isEnabled
        )
    }

    private func parseEnvironment() -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: environmentText
                .split(whereSeparator: \.isNewline)
                .compactMap { line -> (String, String)? in
                    let pieces = line.split(separator: "=", maxSplits: 1).map(String.init)
                    guard pieces.count == 2 else { return nil }
                    return (pieces[0], pieces[1])
                }
        )
    }

    private func buildSchedule() -> SchedulerRule {
        switch scheduleMode {
        case .manual:
            .disabled
        case .interval:
            .interval(minutes: max(Int(intervalMinutes) ?? 0, 0))
        case .daily:
            .daily(hour: max(Int(dailyHour) ?? 0, 0), minute: max(Int(dailyMinute) ?? 0, 0))
        }
    }

    private enum EditorSection: CaseIterable {
        case basic
        case command
        case schedule
        case runtime

        func title(using strings: AppStrings) -> String {
            switch self {
            case .basic: strings.basic
            case .command: strings.commandTitle
            case .schedule: strings.scheduleTitle
            case .runtime: strings.runtime
            }
        }
    }

    private enum ScheduleMode: CaseIterable {
        case manual
        case interval
        case daily

        func title(using strings: AppStrings) -> String {
            switch self {
            case .manual: strings.manual
            case .interval: strings.interval
            case .daily: strings.daily
            }
        }
    }
}

private struct LabeledField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DashboardTheme.textMuted)
            content
        }
    }
}

private struct FilterChipButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isActive ? Color.white : DashboardTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(isActive ? DashboardAccent.running.color : DashboardTheme.panelRaised)
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    let accent: DashboardAccent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(minHeight: 40)
            .padding(.horizontal, 16)
            .background(accent.color.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .foregroundStyle(DashboardTheme.textPrimary)
            .frame(minHeight: 40)
            .padding(.horizontal, 16)
            .background(DashboardTheme.panelRaised.opacity(configuration.isPressed ? 0.86 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DashboardTheme.stroke, lineWidth: 1)
            )
    }
}

struct IconActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(DashboardTheme.textPrimary)
            .frame(width: 40, height: 40)
            .background(DashboardTheme.panelRaised.opacity(configuration.isPressed ? 0.86 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DashboardTheme.stroke, lineWidth: 1)
            )
    }
}

struct DestructiveActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DashboardAccent.danger.color)
            .frame(minHeight: 40)
            .padding(.horizontal, 16)
            .background(DashboardTheme.panelRaised.opacity(configuration.isPressed ? 0.86 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DashboardAccent.danger.color.opacity(0.18), lineWidth: 1)
            )
    }
}

private func statusPill(label: String, accent: DashboardAccent) -> some View {
    Text(label)
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(accent == .neutral ? DashboardTheme.textSecondary : accent.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DashboardTheme.panelRaised, in: Capsule())
}

private func subtlePill(label: String) -> some View {
    Text(label)
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(DashboardTheme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DashboardTheme.panelRaised, in: Capsule())
}

private enum ActivityTab: CaseIterable {
    case latestLog
    case runHistory

    func title(using strings: AppStrings) -> String {
        switch self {
        case .latestLog: strings.latestLog
        case .runHistory: strings.runHistory
        }
    }
}
