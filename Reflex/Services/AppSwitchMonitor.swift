import Foundation
import AppKit
import Combine

@MainActor
class AppSwitchMonitor: ObservableObject {
    @Published var metrics = AppSwitchMetrics()

    /// Total number of app/window switches in the current session.
    private(set) var totalSwitches: Int = 0

    private var switchTimestamps: [Date] = []
    private var currentAppStartTime: Date = .now
    private var appUsageMap: [String: TimeInterval] = [:]
    private var windowStart: Date = .now
    private var isActive: Bool = false
    private var lastFocusedWindowTitle: String = ""
    private var windowPollTimer: Timer?

    func startMonitoring() {
        guard !isActive else { return }
        isActive = true

        let center = NSWorkspace.shared.notificationCenter

        // App activation (switching between different apps)
        center.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // Space/desktop switching
        center.addObserver(
            self,
            selector: #selector(spaceDidChange(_:)),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        if let app = NSWorkspace.shared.frontmostApplication {
            metrics.currentApp = app.localizedName ?? "Unknown"
        }

        // Poll focused window title to detect window switches within the same app
        // (e.g., switching between browser windows across desktops)
        windowPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkFocusedWindow()
            }
        }
    }

    func stopMonitoring() {
        isActive = false
        windowPollTimer?.invalidate()
        windowPollTimer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }

        let now = Date()
        let appName = app.localizedName ?? "Unknown"

        // Record time in previous app
        let timeInPrevApp = now.timeIntervalSince(currentAppStartTime)
        if !metrics.currentApp.isEmpty {
            appUsageMap[metrics.currentApp, default: 0] += timeInPrevApp
        }

        // Record switch
        recordContextSwitch(at: now)

        // Update current app
        metrics.currentApp = appName
        currentAppStartTime = now
        lastFocusedWindowTitle = "" // reset so next poll picks up the new window

        updateMetrics()
    }

    @objc private func spaceDidChange(_ notification: Notification) {
        // Switching desktops/Spaces is a context switch even if the app stays the same
        recordContextSwitch(at: .now)
        updateMetrics()
    }

    /// Polls the focused window title to detect switching between windows of the same app
    private func checkFocusedWindow() {
        guard isActive else { return }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let pid = frontApp.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)

        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard result == .success, let focusedWindow else { return }

        guard CFGetTypeID(focusedWindow) == AXUIElementGetTypeID() else { return }
        let windowRef = unsafeBitCast(focusedWindow, to: AXUIElement.self)
        var titleValue: AnyObject?
        AXUIElementCopyAttributeValue(windowRef, kAXTitleAttribute as CFString, &titleValue)
        let windowTitle = (titleValue as? String) ?? ""

        // If the window title changed within the same app, count as context switch
        if !windowTitle.isEmpty && windowTitle != lastFocusedWindowTitle && !lastFocusedWindowTitle.isEmpty {
            recordContextSwitch(at: .now)
            updateMetrics()
        }

        lastFocusedWindowTitle = windowTitle
    }

    private func recordContextSwitch(at time: Date) {
        totalSwitches += 1
        switchTimestamps.append(time)

        let cutoff = time.addingTimeInterval(-ReflexConstants.appSwitchWindowSeconds)
        switchTimestamps.removeAll { $0 < cutoff }
    }

    private func updateMetrics() {
        let now = Date()
        // Use windowed time (capped at appSwitchWindowSeconds) for rate calculation
        let elapsed = now.timeIntervalSince(windowStart)
        let windowSeconds = min(elapsed, ReflexConstants.appSwitchWindowSeconds)
        let minutesElapsed = max(windowSeconds / 60.0, 0.1)

        metrics.switchesPerMinute = Double(switchTimestamps.count) / minutesElapsed
        metrics.uniqueAppsInWindow = max(Set(appUsageMap.keys).count, 1)
        metrics.rapidSwitchBursts = countRapidSwitchBursts()
        metrics.timeInCurrentApp = now.timeIntervalSince(currentAppStartTime)
        metrics.timestamp = now
    }

    private func countRapidSwitchBursts() -> Int {
        guard switchTimestamps.count >= ReflexConstants.rapidSwitchThreshold else { return 0 }

        var bursts = 0
        let window = ReflexConstants.rapidSwitchWindow

        for i in 0..<switchTimestamps.count {
            let windowEnd = switchTimestamps[i].addingTimeInterval(window)
            let switchesInWindow = switchTimestamps.filter {
                $0 >= switchTimestamps[i] && $0 <= windowEnd
            }.count
            if switchesInWindow >= ReflexConstants.rapidSwitchThreshold {
                bursts += 1
            }
        }

        return bursts
    }

    func reset() {
        totalSwitches = 0
        switchTimestamps.removeAll()
        appUsageMap.removeAll()
        currentAppStartTime = .now
        windowStart = .now
        lastFocusedWindowTitle = ""
        metrics = AppSwitchMetrics()
    }

    deinit {
        windowPollTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
