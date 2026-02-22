import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    private var rightClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force dark mode globally — Reflex is dark-only
        NSApp.appearance = NSAppearance(named: .darkAqua)

        UNUserNotificationCenter.current().delegate = self

        let breakCategory = UNNotificationCategory(
            identifier: "BREAK_REMINDER",
            actions: [
                UNNotificationAction(identifier: "TAKE_BREAK", title: "Take Break", options: [.foreground]),
                UNNotificationAction(identifier: "SNOOZE_5", title: "Snooze 5 min", options: []),
                UNNotificationAction(identifier: "DISMISS", title: "I'm Fine", options: [.destructive]),
            ],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "",
            options: .customDismissAction
        )

        UNUserNotificationCenter.current().setNotificationCategories([breakCategory])

        // Right-click context menu on menu bar icon
        setupStatusItemRightClickMenu()

        // Prompt user to move to /Applications if running from elsewhere
        MoveToApplicationsController.checkAndPromptIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.post(name: .appWillTerminate, object: nil)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case "TAKE_BREAK":
            NotificationCenter.default.post(name: .takeBreak, object: nil)
        case "SNOOZE_5":
            NotificationCenter.default.post(name: .snoozeBreak, object: nil, userInfo: ["minutes": 5])
        case "DISMISS":
            NotificationCenter.default.post(name: .dismissBreak, object: nil)
        default:
            break
        }
        completionHandler()
    }

    // MARK: - Right-Click Menu on Status Bar Icon

    private func setupStatusItemRightClickMenu() {
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseUp) { event in
            // Only intercept right-clicks on our status bar window
            guard let window = event.window,
                  String(describing: type(of: window)).contains("NSStatusBarWindow") else {
                return event
            }

            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Quit Reflex Beta", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

            if let view = window.contentView {
                NSMenu.popUpContextMenu(menu, with: event, for: view)
            }
            return nil // consume the event
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let takeBreak = Notification.Name("com.reflex.takeBreak")
    static let snoozeBreak = Notification.Name("com.reflex.snoozeBreak")
    static let skipBreak = Notification.Name("com.reflex.skipBreak")
    static let dismissBreak = Notification.Name("com.reflex.dismissBreak")
    static let endBreakEarly = Notification.Name("com.reflex.endBreakEarly")
    static let breakEnded = Notification.Name("com.reflex.breakEnded")
    static let navigateToDashboardTab = Notification.Name("com.reflex.navigateToDashboardTab")
    static let showOnboarding = Notification.Name("com.reflex.showOnboarding")
    static let appWillTerminate = Notification.Name("com.reflex.appWillTerminate")
    static let startEyeRest = Notification.Name("com.reflex.startEyeRest")
    static let skipEyeRest = Notification.Name("com.reflex.skipEyeRest")
    static let dismissEyeRest = Notification.Name("com.reflex.dismissEyeRest")
}
