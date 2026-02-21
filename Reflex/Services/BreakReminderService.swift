import Foundation

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

    let overlayController = BreakOverlayWindowController()
    let cursorFollower = CursorFollowerWindowController()
    let notificationPopup = BreakNotificationPopupController()

    private var breakTimer: Timer?
    private var snoozeTimer: Timer?
    private var preBreakTimer: Timer?
    private var focusTimer: Timer?
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
    func sendBreakReminder(loadScore: Int, minutesAtHighLoad: Int) {
        guard reminderEnabled else { return }

        // Show cursor-following countdown
        cursorFollower.show(countdownSeconds: preBreakCountdown)

        // Show top-right notification popup
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
    }
}
