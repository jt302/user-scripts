import XCTest
@testable import UserScriptsApp

final class AppLanguageTests: XCTestCase {
    func testSystemLanguageResolvesChineseForChineseLocale() {
        let strings = AppStrings(
            preference: .system,
            preferredLanguages: ["zh-Hans-CN"],
            locale: Locale(identifier: "en_US")
        )
        XCTAssertEqual(strings.newScript, "新建脚本")
    }

    func testSystemLanguageUsesPreferredLanguagesInsteadOfLocale() {
        let strings = AppStrings(
            preference: .system,
            preferredLanguages: ["zh-Hans-CN"],
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(strings.languageTitle, "语言")
    }

    func testEnglishPreferenceUsesEnglishCopy() {
        let strings = AppStrings(
            preference: .english,
            preferredLanguages: ["zh-Hans-CN"],
            locale: Locale(identifier: "zh-Hans_CN")
        )
        XCTAssertEqual(strings.newScript, "New Script")
        XCTAssertEqual(strings.filterTitle(SidebarFilter.failed), "Failed")
    }

    func testChinesePreferenceUsesChineseCopy() {
        let strings = AppStrings(
            preference: .chinese,
            preferredLanguages: ["en-US"],
            locale: Locale(identifier: "en_US")
        )
        XCTAssertEqual(strings.settingsButton, "设置")
        XCTAssertEqual(strings.filterTitle(SidebarFilter.running), "运行中")
    }
}
