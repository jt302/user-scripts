import SwiftUI

enum AppThemePreference: String, CaseIterable, Identifiable {
    case system
    case dark
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            "System"
        case .dark:
            "Dark"
        case .light:
            "Light"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .dark:
            .dark
        case .light:
            .light
        }
    }

    func title(using strings: AppStrings) -> String {
        switch self {
        case .system:
            strings.system
        case .dark:
            strings.dark
        case .light:
            strings.light
        }
    }
}
