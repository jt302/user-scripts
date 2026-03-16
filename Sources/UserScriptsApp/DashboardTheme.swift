import AppKit
import SwiftUI

enum DashboardTheme {
    static let window = dynamicColor(
        light: NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.97, alpha: 1),
        dark: NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.11, alpha: 1)
    )
    static let sidebar = dynamicColor(
        light: NSColor(calibratedRed: 0.93, green: 0.94, blue: 0.96, alpha: 1),
        dark: NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.13, alpha: 1)
    )
    static let panel = dynamicColor(
        light: NSColor(calibratedRed: 0.985, green: 0.985, blue: 0.99, alpha: 1),
        dark: NSColor(calibratedRed: 0.14, green: 0.15, blue: 0.16, alpha: 1)
    )
    static let panelRaised = dynamicColor(
        light: NSColor(calibratedRed: 0.93, green: 0.94, blue: 0.96, alpha: 1),
        dark: NSColor(calibratedRed: 0.18, green: 0.19, blue: 0.20, alpha: 1)
    )
    static let stroke = dynamicColor(
        light: NSColor.black.withAlphaComponent(0.08),
        dark: NSColor.white.withAlphaComponent(0.08)
    )
    static let textPrimary = dynamicColor(
        light: NSColor(calibratedWhite: 0.08, alpha: 1),
        dark: NSColor.white.withAlphaComponent(0.94)
    )
    static let textSecondary = dynamicColor(
        light: NSColor(calibratedWhite: 0.28, alpha: 1),
        dark: NSColor.white.withAlphaComponent(0.62)
    )
    static let textMuted = dynamicColor(
        light: NSColor(calibratedWhite: 0.45, alpha: 1),
        dark: NSColor.white.withAlphaComponent(0.42)
    )

    private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let match = appearance.bestMatch(from: [.darkAqua, .aqua, .vibrantDark, .vibrantLight])
                switch match {
                case .darkAqua, .vibrantDark:
                    return dark
                default:
                    return light
                }
            }
        )
    }
}

extension DashboardAccent {
    var color: Color {
        switch self {
        case .neutral:
            Color(nsColor: NSColor(calibratedRed: 0.42, green: 0.48, blue: 0.58, alpha: 1))
        case .running:
            Color(nsColor: NSColor(calibratedRed: 0.22, green: 0.53, blue: 0.96, alpha: 1))
        case .warning:
            Color(nsColor: NSColor(calibratedRed: 0.78, green: 0.61, blue: 0.18, alpha: 1))
        case .danger:
            Color(nsColor: NSColor(calibratedRed: 0.84, green: 0.37, blue: 0.32, alpha: 1))
        case .success:
            Color(nsColor: NSColor(calibratedRed: 0.25, green: 0.63, blue: 0.43, alpha: 1))
        }
    }

    var subtleBackground: Color {
        color.opacity(0.16)
    }
}

struct DashboardCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(DashboardTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DashboardTheme.stroke, lineWidth: 1)
            )
    }
}

extension View {
    func dashboardCard() -> some View {
        modifier(DashboardCardModifier())
    }
}
