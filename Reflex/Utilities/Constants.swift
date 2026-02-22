import Foundation
import SwiftUI

enum ReflexConstants {
    // MARK: - Monitoring Windows
    static let keystrokeWindowSize = 120
    static let mouseWindowSize = 300
    static let appSwitchWindowSeconds: TimeInterval = 300
    static let loadSampleInterval: TimeInterval = 5

    // MARK: - Cognitive Load Weights
    static let typingVarianceWeight: Double = 0.25
    static let errorRateWeight: Double = 0.20
    static let appSwitchWeight: Double = 0.20
    static let mouseJitterWeight: Double = 0.15
    static let pauseFrequencyWeight: Double = 0.10
    static let scrollBehaviorWeight: Double = 0.10

    // MARK: - Thresholds
    static let pauseThreshold: TimeInterval = 2.0
    static let rapidSwitchWindow: TimeInterval = 30
    static let rapidSwitchThreshold = 3
    static let highLoadThreshold = 70
    static let overloadedThreshold = 85
    static let breakReminderDuration: TimeInterval = 900

    // MARK: - Smoothing
    static let emaAlpha: Double = 0.15

    // MARK: - Baseline
    static let baselineCalibrationDuration: TimeInterval = 900

    // MARK: - Time-Based Breaks
    static let defaultFocusBreakIntervalMinutes = 25
    static let naturalBreakThreshold: TimeInterval = 120 // 2 min no input = natural break
    static let activityCheckInterval: TimeInterval = 30

    // MARK: - Fatigue Factor
    static let fatigueOnsetMinutes: Double = 30
    static let fatigueMaxBonus: Double = 25
    static let fatiguePeakMinutes: Double = 120

    // MARK: - Eye Rest (20-20-20 Rule — relaxed default: every 40 min)
    static let eyeRestDefaultIntervalMinutes = 40
    static let eyeRestDuration: TimeInterval = 20
    static let eyeRestPreCountdown: Int = 15

    // MARK: - Hydration
    static let hydrationDefaultIntervalMinutes = 60

    // MARK: - UI
    static let menuBarPopoverWidth: CGFloat = 340
    static let menuBarPopoverHeight: CGFloat = 510
    static let dashboardMinWidth: CGFloat = 800
    static let dashboardMinHeight: CGFloat = 600
    static let cardCornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 12

    // MARK: - Animation
    static let pulseAnimationDuration: Double = 2.0
    static let gradientAnimationDuration: Double = 8.0

    // MARK: - Colors
    static let brandGradient: [Color] = [
        Color(red: 0.2, green: 0.1, blue: 0.5),
        Color(red: 0.1, green: 0.3, blue: 0.6),
        Color(red: 0.0, green: 0.5, blue: 0.5),
        Color(red: 0.1, green: 0.2, blue: 0.4),
    ]

    // MARK: - Storage
    static let appSupportDirectory = "Reflex"
    static let sessionsDirectory = "sessions"
    static let baselineFileName = "baseline.json"
}
