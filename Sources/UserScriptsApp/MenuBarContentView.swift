import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var panelController: MenuBarPanelController
    @Environment(\.openWindow) private var openWindow

    private var strings: AppStrings { model.strings }

    var body: some View {
        let state = model.dashboardState

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(strings.appName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(DashboardTheme.textPrimary)
                    Text(state.hero.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Text(state.hero.statusLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(state.hero.accent == .neutral ? DashboardTheme.textSecondary : state.hero.accent.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DashboardTheme.panelRaised, in: Capsule())
            }

            if let bannerMessage = model.bannerMessage {
                BannerStrip(message: bannerMessage, accent: state.hero.accent)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if state.menuBarItems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(strings.noScriptsYet)
                        .foregroundStyle(DashboardTheme.textPrimary)
                        .font(.system(size: 14, weight: .semibold))
                    Text(strings.menuBarEmptyBody())
                        .foregroundStyle(DashboardTheme.textSecondary)
                        .font(.system(size: 12))
                    Button(strings.newScript) {
                        openWindow(id: "manager")
                        panelController.close()
                    }
                    .buttonStyle(PrimaryActionButtonStyle(accent: .running))
                }
                .dashboardCard()
            } else {
                VStack(spacing: 10) {
                    ForEach(state.menuBarItems) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(item.accent.color)
                                .frame(width: 9, height: 9)
                                .padding(.top, 5)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .foregroundStyle(DashboardTheme.textPrimary)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(item.subtitle)
                                    .foregroundStyle(DashboardTheme.textSecondary)
                                    .font(.system(size: 11))
                                    .lineLimit(2)
                            }

                            Spacer(minLength: 12)

                            if model.runningHandles[item.id] != nil {
                                Button(strings.stop) {
                                    Task { await model.stop(scriptID: item.id) }
                                    panelController.closeAndDeactivate()
                                }
                                .buttonStyle(SecondaryActionButtonStyle())
                            } else {
                                Button(strings.start) {
                                    Task { await model.start(scriptID: item.id, source: .manual) }
                                    panelController.closeAndDeactivate()
                                }
                                .buttonStyle(PrimaryActionButtonStyle(accent: .running))
                            }
                        }
                        .padding(14)
                        .background(DashboardTheme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(DashboardTheme.stroke, lineWidth: 1)
                        )
                    }
                }
            }

            Divider().overlay(DashboardTheme.stroke)

            HStack(spacing: 10) {
                Button(strings.openConsole) {
                    openWindow(id: "manager")
                    panelController.close()
                }
                .buttonStyle(PrimaryActionButtonStyle(accent: .running))

                Button(strings.newScript) {
                    openWindow(id: "manager")
                    panelController.close()
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Spacer()

                Button(strings.quit) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
        .padding(16)
        .frame(width: 430)
        .preferredColorScheme(model.preferredColorScheme)
        .background(DashboardTheme.window)
        .background(
            WindowAccessor { window in
                panelController.attach(window: window)
            }
        )
        .animation(.easeInOut(duration: 0.22), value: model.bannerMessage)
    }
}
