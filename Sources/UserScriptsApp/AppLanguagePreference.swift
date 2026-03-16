import Foundation

enum AppLanguagePreference: String, CaseIterable, Identifiable {
    case system
    case english
    case chinese

    var id: String { rawValue }

    func title(using strings: AppStrings) -> String {
        switch self {
        case .system:
            strings.system
        case .english:
            strings.english
        case .chinese:
            strings.chinese
        }
    }
}
