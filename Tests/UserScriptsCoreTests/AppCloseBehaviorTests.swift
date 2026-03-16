import AppKit
import XCTest
@testable import UserScriptsApp

@MainActor
final class AppCloseBehaviorTests: XCTestCase {
    func testKeepInMenuBarCancelsTermination() {
        let model = AppModel()
        model.setCloseBehaviorPreference(.keepInMenuBar)

        let reply = model.handleAppTerminationRequest(allWindows: [])

        XCTAssertEqual(reply, .terminateCancel)
    }

    func testQuitPreferenceAllowsTermination() {
        let model = AppModel()
        model.setCloseBehaviorPreference(.quit)

        let reply = model.handleAppTerminationRequest(allWindows: [])

        XCTAssertEqual(reply, .terminateNow)
    }

    func testKeepInMenuBarQuitCommandDoesNotRequestTermination() {
        let model = AppModel()
        model.setCloseBehaviorPreference(.keepInMenuBar)

        let shouldTerminate = model.handleQuitCommand(allWindows: [])

        XCTAssertFalse(shouldTerminate)
    }
}
