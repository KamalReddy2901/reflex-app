import Foundation
import UserNotifications

@MainActor
class BreakReminderService: ObservableObject {
    @Published var breaksTaken: Int = 0
    @Published var lastBreakTime: Date?
    @Published var isOnBreak: Bool = false
    @Published var breakDuration: TimeInterval = 0
    @Published var breakRemaining: TimeInterval = 0
    @Published var showBreakOverlay: Bool = false
    @Published var sessionStartTime: Date = .now
    @Published var totalFocusSeconds: TimeInterval = 0

    // Eye Rest
    @Published var eyeRestEnabled: Bool = true
    @Published var eyeRestIntervalMinutes: Int = ReflexConstants.eyeRestDefaultIntervalMinutes
    @Published var showEyeRestOverlay: Bool = false
    @Published var eyeRestRemaining: TimeInterval = ReflexConstants.eyeRestDuration
    @Published var isEyeResting: Bool = false
    @Published var lastEyeRestTime: Date = .now

    // Time-based breaks
    @Published var focusBreakIntervalMinutes: Int = ReflexConstants.defaultFocusBreakIntervalMinutes

    // Hydration
    @Published var hydrationReminderEnabled: Bool = false
    @Published var hydrationIntervalMinutes: Int = ReflexConstants.hydrationDefaultIntervalMinutes
    @Published var lastHydrationReminder: Date = .now

    // Natural break detection
    @Published var naturalBreaksTaken: Int = 0

    // Skip escalation
    @Published var consecutiveSkips: Int = 0

    let overlayController = BreakOverlayWindowController()
    let cursorFollower = CursorFollowerWindowController()
    let notificationPopup = BreakNotificationPopupController()
    let eyeRestOverlayController = EyeRestOverlayWindowController()

    private var breakTimer: Timer?
    private var snoozeTimer: Timer?
    private var preBreakTimer: Timer?
    private var focusTimer: Timer?
    private var eyeRestTimer: Timer?
    private var eyeRestPreTimer: Timer?
    private var reminderEnabled: Bool = true
    private var reminderInterval: TimeInterval = ReflexConstants.breakReminderDuration

    // User preferences (synced from @AppStorage in views)
    var selectedBreakDurationMinutes: Int = 5
    var breathingExerciseEnabled: Bool = true

    private var selectedBreakLength: TimeInterval {
        TimeInterval(selectedBreakDurationMinutes * 60)
    }

    private let preBreakCountdown: Int = 30 // seconds before auto-start

    func startSession() {
        sessionStartTime = .now
        focusTimer?.invalidate()
        focusTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, !self.isOnBreak else { return }
                self.totalFocusSeconds += 1
            }
        }
    }

    // MARK: - Break Reminder Flow (DeskRest-style)

    /// Step 1: Show cursor follower + top-right popup with 30s countdown
    /// Whether any break/eye-rest UI is currently active (prevents overlapping triggers)
    var isShowingAnyPrompt: Bool {
        cursorFollower.isVisible || notificationPopup.isVisible || isOnBreak || isEyeResting
    }

    func sendBreakReminder(loadScore: Int, minutesAtHighLoad: Int) {
        guard reminderEnabled, !isShowingAnyPrompt else { return }

        // Show cursor-following countdown
        cursorFollower.show(countdownSeconds: preBreakCountdown)

        // Only set mode to .breakReminder if not already overridden by caller
        // (e.g. checkTimedBreak sets .timedBreak before calling this)
        // Mode should be set BEFORE calling this method if a custom mode is needed.
        notificationPopup.show(
            loadScore: loadScore,
            minutesAtHighLoad: minutesAtHighLoad,
            countdown: preBreakCountdown
        )

        showBreakOverlay = true

        // Start pre-break countdown timer
        var remaining = preBreakCountdown
        preBreakTimer?.invalidate()
        preBreakTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else { timer.invalidate(); return }
                remaining -= 1
                self.cursorFollower.tick()
                self.notificationPopup.updateCountdown(remaining)

                if remaining <= 0 {
                    timer.invalidate()
                    self.preBreakTimer = nil
                    // Auto-start break if user hasn't interacted
                    if self.cursorFollower.isVisible {
                        self.startBreak()
                    }
                }
            }
        }
    }

    /// Step 2: Start the actual break (fullscreen overlay with countdown)
    func startBreak(durationMinutes: Int? = nil) {
        // Dismiss pre-break UI
        cursorFollower.dismiss()
        notificationPopup.dismiss()
        preBreakTimer?.invalidate()
        preBreakTimer = nil

        // Use provided duration or fall back to preference
        let effectiveDuration: TimeInterval
        if let mins = durationMinutes {
            effectiveDuration = TimeInterval(mins * 60)
        } else {
            effectiveDuration = selectedBreakLength
        }

        isOnBreak = true
        lastBreakTime = .now
        lastEyeRestTime = .now // Reset eye rest timer on explicit break
        consecutiveSkips = 0
        breakDuration = 0
        breakRemaining = effectiveDuration
        showBreakOverlay = true

        // Show fullscreen countdown (with or without breathing)
        overlayController.showBreakCountdown(
            duration: effectiveDuration,
            breathing: breathingExerciseEnabled
        )

        breakTimer?.invalidate()
        breakTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isOnBreak else { return }
                self.breakDuration += 1
                self.breakRemaining = max(0, effectiveDuration - self.breakDuration)

                self.overlayController.updateCountdown(
                    remaining: self.breakRemaining,
                    total: effectiveDuration
                )

                if self.breakRemaining <= 0 {
                    self.completeBreak()
                }
            }
        }
    }

    /// Break ended naturally (timer ran out)
    private func completeBreak() {
        isOnBreak = false
        breaksTaken += 1
        breakTimer?.invalidate()
        breakTimer = nil

        overlayController.showCompleted()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.overlayController.dismiss()
            self?.showBreakOverlay = false
        }
    }

    /// User chose to skip break entirely — show gentle message
    func skipBreak() {
        cursorFollower.dismiss()
        notificationPopup.dismiss()
        preBreakTimer?.invalidate()
        preBreakTimer = nil

        consecutiveSkips += 1

        // Show gentle fullscreen message
        overlayController.showSkipMessage()
        showBreakOverlay = true

        // Auto-dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.overlayController.dismiss()
            self?.showBreakOverlay = false
        }
    }

    /// User ended break early
    func endBreakEarly() {
        isOnBreak = false
        breaksTaken += 1
        breakTimer?.invalidate()
        breakTimer = nil
        showBreakOverlay = false
        overlayController.dismiss()
    }

    func endBreak() {
        endBreakEarly()
    }

    func snooze(minutes: Int) {
        cursorFollower.dismiss()
        notificationPopup.dismiss()
        preBreakTimer?.invalidate()
        preBreakTimer = nil
        showBreakOverlay = false
        overlayController.dismiss()

        snoozeTimer?.invalidate()
        snoozeTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.sendBreakReminder(loadScore: 70, minutesAtHighLoad: minutes)
            }
        }
    }

    func dismiss() {
        cursorFollower.dismiss()
        notificationPopup.dismiss()
        preBreakTimer?.invalidate()
        preBreakTimer = nil
        showBreakOverlay = false
        overlayController.dismiss()
    }

    // MARK: - Eye Rest (20-20-20 Rule)

    /// Triggers the eye rest flow: cursor follower (15s) → popup → fullscreen overlay (20s)
    func triggerEyeRest() {
        guard eyeRestEnabled, !isShowingAnyPrompt else { return }

        // Show cursor-following countdown (15 seconds)
        cursorFollower.show(countdownSeconds: ReflexConstants.eyeRestPreCountdown)

        // Show notification popup in eye rest mode
        notificationPopup.mode = .eyeRest
        notificationPopup.show(
            loadScore: 0,
            minutesAtHighLoad: 0,
            countdown: ReflexConstants.eyeRestPreCountdown
        )

        // Start pre-countdown timer
        var remaining = ReflexConstants.eyeRestPreCountdown
        eyeRestPreTimer?.invalidate()
        eyeRestPreTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else { timer.invalidate(); return }
                remaining -= 1
                self.cursorFollower.tick()
                self.notificationPopup.updateCountdown(remaining)

                if remaining <= 0 {
                    timer.invalidate()
                    self.eyeRestPreTimer = nil
                    // Auto-start eye rest if user hasn't skipped
                    if self.cursorFollower.isVisible {
                        self.startEyeRest()
                    }
                }
            }
        }
    }

    /// Start the actual eye rest overlay (20s countdown)
    func startEyeRest() {
        // Dismiss pre-UI
        cursorFollower.dismiss()
        notificationPopup.dismiss()
        eyeRestPreTimer?.invalidate()
        eyeRestPreTimer = nil

        isEyeResting = true
        showEyeRestOverlay = true
        eyeRestRemaining = ReflexConstants.eyeRestDuration

        eyeRestOverlayController.show(duration: ReflexConstants.eyeRestDuration)

        eyeRestTimer?.invalidate()
        eyeRestTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isEyeResting else { return }
                self.eyeRestRemaining -= 1
                self.eyeRestOverlayController.updateCountdown(remaining: self.eyeRestRemaining)

                if self.eyeRestRemaining <= 0 {
                    self.completeEyeRest()
                }
            }
        }
    }

    /// Eye rest completed naturally
    private func completeEyeRest() {
        isEyeResting = false
        lastEyeRestTime = .now
        eyeRestTimer?.invalidate()
        eyeRestTimer = nil

        eyeRestOverlayController.showCompleted()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.eyeRestOverlayController.dismiss()
            self?.showEyeRestOverlay = false
        }
    }

    /// User skipped eye rest
    func skipEyeRest() {
        cursorFollower.dismiss()
        notificationPopup.dismiss()
        eyeRestPreTimer?.invalidate()
        eyeRestPreTimer = nil
        isEyeResting = false
        eyeRestTimer?.invalidate()
        eyeRestTimer = nil
        lastEyeRestTime = .now // Reset timer so it doesn't immediately re-trigger
        showEyeRestOverlay = false
        eyeRestOverlayController.dismiss()
    }

    func dismissEyeRest() {
        skipEyeRest()
    }

    /// Check if eye rest should be triggered based on elapsed focus time
    func checkEyeRest() {
        guard eyeRestEnabled, !isShowingAnyPrompt else { return }

        let minutesSinceLastEyeRest = Int(Date.now.timeIntervalSince(lastEyeRestTime) / 60)
        if minutesSinceLastEyeRest >= eyeRestIntervalMinutes {
            triggerEyeRest()
        }
    }

    // MARK: - Time-Based Break Reminders

    /// Check if a time-based break should be triggered (independent of cognitive load)
    func checkTimedBreak(continuousActiveMinutes: Int, hasTriggeredTimedBreak: Bool) -> Bool {
        guard reminderEnabled, !isShowingAnyPrompt else { return false }

        if continuousActiveMinutes >= focusBreakIntervalMinutes && !hasTriggeredTimedBreak {
            // Set mode BEFORE calling sendBreakReminder (which no longer overrides it)
            notificationPopup.mode = .timedBreak(minutesFocused: continuousActiveMinutes)
            sendBreakReminder(
                loadScore: max(40, Int(Double(continuousActiveMinutes) / Double(focusBreakIntervalMinutes) * 50)),
                minutesAtHighLoad: continuousActiveMinutes
            )
            return true
        }
        return false
    }

    // MARK: - Hydration Reminders

    func checkHydrationReminder() {
        guard hydrationReminderEnabled else { return }

        let minutesSinceLastReminder = Int(Date.now.timeIntervalSince(lastHydrationReminder) / 60)
        if minutesSinceLastReminder >= hydrationIntervalMinutes {
            sendHydrationReminder()
            lastHydrationReminder = .now
        }
    }

    private func sendHydrationReminder() {
        // Ensure notification permission is granted
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        let content = UNMutableNotificationContent()
        content.title = "💧 Stay Hydrated"
        content.body = "You've been working for a while. Take a sip of water!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "hydration-\(Date.now.timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Natural Break Detection

    /// Called when the system detects the user has been idle for 2+ minutes
    func recordNaturalBreak() {
        naturalBreaksTaken += 1
        lastBreakTime = .now
        lastEyeRestTime = .now // Reset eye rest timer too
        consecutiveSkips = 0
    }

    func setReminderEnabled(_ enabled: Bool) {
        reminderEnabled = enabled
    }

    func setReminderInterval(_ interval: TimeInterval) {
        reminderInterval = interval
    }

    /// Formatted session duration string
    var sessionDuration: String {
        let total = Int(Date().timeIntervalSince(sessionStartTime))
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }

    /// Formatted focus time string
    var focusTimeFormatted: String {
        let total = Int(totalFocusSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }

    deinit {
        breakTimer?.invalidate()
        snoozeTimer?.invalidate()
        preBreakTimer?.invalidate()
        focusTimer?.invalidate()
        eyeRestTimer?.invalidate()
        eyeRestPreTimer?.invalidate()
    }
}
