import Foundation
import UserNotifications

actor NotificationController {
    private var authorizationRequested = false

    func prepare() async {
        guard !authorizationRequested else {
            return
        }
        authorizationRequested = true
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func send(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
