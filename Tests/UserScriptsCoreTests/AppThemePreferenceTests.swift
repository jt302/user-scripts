import SwiftUI
import XCTest
@testable import UserScriptsApp

final class AppThemePreferenceTests: XCTestCase {
    func testSystemThemeUsesSystemAppearance() {
        XCTAssertNil(AppThemePreference.system.colorScheme)
    }

    func testDarkThemeResolvesToDarkColorScheme() {
        XCTAssertEqual(AppThemePreference.dark.colorScheme, .dark)
    }

    func testLightThemeResolvesToLightColorScheme() {
        XCTAssertEqual(AppThemePreference.light.colorScheme, .light)
    }
}
