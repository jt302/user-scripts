import Foundation

enum AppCloseBehaviorPreference: String, CaseIterable, Identifiable {
    case ask
    case keepInMenuBar
    case quit

    var id: String { rawValue }

    func title(using strings: AppStrings) -> String {
        switch self {
        case .ask:
            strings.askEveryTime
        case .keepInMenuBar:
            strings.keepInMenuBar
        case .quit:
            strings.quitApp
        }
    }
}
