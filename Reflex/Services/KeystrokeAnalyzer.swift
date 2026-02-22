import Foundation
import Combine

@MainActor
class KeystrokeAnalyzer: ObservableObject {
    @Published var metrics = TypingMetrics()

    private var keyTimestamps = RingBuffer<TimeInterval>(capacity: ReflexConstants.keystrokeWindowSize)
    private var intervals = RingBuffer<TimeInterval>(capacity: ReflexConstants.keystrokeWindowSize - 1)
    private var lastKeyTime: Date?
    private var totalKeystrokes: Int = 0
    private var backspaceCount: Int = 0
    private var pauseCount: Int = 0
    /// Windowed counters for recent-only rate metrics
    private var windowedKeystrokes: Int = 0
    private var windowedBackspaces: Int = 0
    private var windowedPauses: Int = 0
    private var windowStart: Date = .now
    private var recentKeyCount: Int = 0
    private var lastWindowResetTime: Date = .now
    private var recentKeyTimer: Timer?

    init() {
        recentKeyTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.recentKeyCount = 0
                self.lastWindowResetTime = .now
                // Reset windowed counters every 60s to keep metrics fresh
                self.windowedKeystrokes = 0
                self.windowedBackspaces = 0
                self.windowedPauses = 0
                self.windowStart = .now
            }
        }
    }

    func recordKeystroke(at time: Date) {
        totalKeystrokes += 1
        windowedKeystrokes += 1
        recentKeyCount += 1

        if let lastTime = lastKeyTime {
            let interval = time.timeIntervalSince(lastTime)

            // Only record intervals < 10s (longer = user stepped away)
            if interval < 10.0 {
                intervals.append(interval)

                if interval > ReflexConstants.pauseThreshold {
                    pauseCount += 1
                    windowedPauses += 1
                }
            }
        }

        lastKeyTime = time
        keyTimestamps.append(time.timeIntervalSince1970)

        updateMetrics()
    }

    func recordBackspace(at time: Date) {
        backspaceCount += 1
        windowedBackspaces += 1
        recordKeystroke(at: time)
    }

    private func updateMetrics() {
        let elapsed = Date.now.timeIntervalSince(windowStart)
        let minutesElapsed = max(elapsed / 60.0, 0.1)

        metrics.averageInterval = intervals.mean
        metrics.intervalVariance = intervals.variance
        metrics.coefficientOfVariation = intervals.coefficientOfVariation
        // Use windowed counters for backspace ratio and pause frequency so they stay responsive
        metrics.backspaceRatio = windowedKeystrokes > 0 ? Double(windowedBackspaces) / Double(windowedKeystrokes) : 0
        metrics.pauseFrequency = Double(windowedPauses) / minutesElapsed

        // Overall WPM: keystrokes in current 60s window / 5 chars per word / elapsed minutes in window
        let windowElapsed = Date.now.timeIntervalSince(lastWindowResetTime)
        let windowMinutes = max(windowElapsed / 60.0, 0.1)
        metrics.wordsPerMinute = Double(recentKeyCount) / 5.0 / windowMinutes

        // Burst WPM: raw typing speed during active typing only (excludes pauses/idle)
        let avgInterval = intervals.mean
        if avgInterval > 0 && intervals.count > 2 {
            metrics.burstWordsPerMinute = min(200, 60.0 / (avgInterval * 5.0))
        } else {
            metrics.burstWordsPerMinute = 0
        }

        metrics.totalKeystrokes = totalKeystrokes
        metrics.recentKeystrokes = recentKeyCount
        metrics.timestamp = .now
    }

    func reset() {
        keyTimestamps.clear()
        intervals.clear()
        lastKeyTime = nil
        totalKeystrokes = 0
        backspaceCount = 0
        pauseCount = 0
        windowedKeystrokes = 0
        windowedBackspaces = 0
        windowedPauses = 0
        recentKeyCount = 0
        windowStart = .now
        lastWindowResetTime = .now
        metrics = TypingMetrics()
    }

    deinit {
        recentKeyTimer?.invalidate()
    }
}
