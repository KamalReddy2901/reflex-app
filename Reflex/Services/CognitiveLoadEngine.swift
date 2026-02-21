import Foundation
import Combine

@MainActor
class CognitiveLoadEngine: ObservableObject {
    @Published var currentScore: Int = 0
    @Published var loadLevel: CognitiveLoadLevel = .flow
    @Published var smoothedScore: Double = 0
    @Published var suggestion: String = "Start working — Reflex is learning your patterns."
    @Published var loadHistory: [LoadSample] = []
    @Published var isCalibrating: Bool = true
    @Published var minutesAtHighLoad: Int = 0

    /// Tracks whether a break reminder has already been triggered for the
    /// current high-load period, preventing repeated reminders.
    var hasTriggeredBreak: Bool = false

    /// Sensitivity multiplier (0.0 = low sensitivity, 1.0 = high sensitivity).
    /// Applied to the raw score to make load detection more/less aggressive.
    var sensitivityMultiplier: Double = 0.5

    private let keystrokeAnalyzer: KeystrokeAnalyzer
    private let mouseAnalyzer: MouseBehaviorAnalyzer
    private let appSwitchMonitor: AppSwitchMonitor

    private var updateTimer: Timer?
    private var highLoadStart: Date?
    private var baseline: BehaviorBaseline?
    private var calibrationStart: Date = .now
    private var calibrationSamples: [BehaviorSnapshot] = []

    struct BehaviorBaseline: Codable {
        var typingIntervalMean: Double
        var typingIntervalCV: Double
        var backspaceRatio: Double
        var mouseJitter: Double
        var appSwitchRate: Double
    }

    init(keystrokeAnalyzer: KeystrokeAnalyzer, mouseAnalyzer: MouseBehaviorAnalyzer, appSwitchMonitor: AppSwitchMonitor) {
        self.keystrokeAnalyzer = keystrokeAnalyzer
        self.mouseAnalyzer = mouseAnalyzer
        self.appSwitchMonitor = appSwitchMonitor

        loadBaseline()
    }

    func startEngine() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: ReflexConstants.loadSampleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.computeLoad()
            }
        }
    }

    func stopEngine() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func computeLoad() {
        let snapshot = createSnapshot()

        // During calibration, collect samples
        if isCalibrating {
            calibrationSamples.append(snapshot)
            if Date.now.timeIntervalSince(calibrationStart) >= ReflexConstants.baselineCalibrationDuration {
                finalizeCalibration()
            }
        }

        let rawScore = computeHeuristicScore(snapshot: snapshot)

        // Exponential moving average for smoothing
        smoothedScore = smoothedScore * (1 - ReflexConstants.emaAlpha) + Double(rawScore) * ReflexConstants.emaAlpha
        currentScore = Int(smoothedScore.rounded())
        loadLevel = CognitiveLoadLevel.from(score: currentScore)
        suggestion = generateSuggestion()

        // Record sample
        let sample = LoadSample(timestamp: .now, score: currentScore, level: loadLevel)
        loadHistory.append(sample)

        // Keep only last hour of history
        let oneHourAgo = Date.now.addingTimeInterval(-3600)
        loadHistory.removeAll { $0.timestamp < oneHourAgo }

        trackHighLoad()
    }

    private func computeHeuristicScore(snapshot: BehaviorSnapshot) -> Int {
        // 1. Typing variance score (higher CV = more cognitive load)
        let typingScore = normalizeScore(
            value: snapshot.typingIntervalCV,
            low: 0.1, high: 0.8,
            baseline: baseline?.typingIntervalCV
        )

        // 2. Error rate score (higher backspace ratio = more load)
        let errorScore = normalizeScore(
            value: snapshot.backspaceRatio,
            low: 0.02, high: 0.15,
            baseline: baseline?.backspaceRatio
        )

        // 3. App switch score (higher switch rate = more load)
        let switchScore = normalizeScore(
            value: snapshot.appSwitchRate,
            low: 1.0, high: 8.0,
            baseline: baseline?.appSwitchRate
        )

        // 4. Mouse jitter score — variance of mouse velocity (px²/s²)
        // Calm: <50K, Normal: 50K-200K, Jittery: 200K-600K, Erratic: >600K
        let jitterScore = normalizeScore(
            value: snapshot.mouseJitter,
            low: 50_000, high: 600_000,
            baseline: baseline?.mouseJitter
        )

        // 5. Pause frequency (more pauses = more struggling)
        let pauseScore = normalizeScore(
            value: snapshot.pauseFrequency,
            low: 0.5, high: 5.0,
            baseline: nil
        )

        // 6. Scroll direction changes (more = searching/lost)
        let scrollScore = normalizeScore(
            value: snapshot.scrollDirectionChanges,
            low: 2, high: 15,
            baseline: nil
        )

        let score = typingScore * ReflexConstants.typingVarianceWeight
            + errorScore * ReflexConstants.errorRateWeight
            + switchScore * ReflexConstants.appSwitchWeight
            + jitterScore * ReflexConstants.mouseJitterWeight
            + pauseScore * ReflexConstants.pauseFrequencyWeight
            + scrollScore * ReflexConstants.scrollBehaviorWeight

        // Apply sensitivity: 0.0 → 0.7x (low), 0.5 → 1.0x (normal), 1.0 → 1.3x (high)
        let sensitivityFactor = 0.7 + sensitivityMultiplier * 0.6
        return Int(min(100, max(0, score * 100 * sensitivityFactor)))
    }

    private func normalizeScore(value: Double, low: Double, high: Double, baseline: Double?) -> Double {
        let ref = baseline ?? low
        let adjustedLow = min(ref, low)
        let range = high - adjustedLow
        guard range > 0 else { return 0 }
        return min(1.0, max(0, (value - adjustedLow) / range))
    }

    private func trackHighLoad() {
        if currentScore >= ReflexConstants.highLoadThreshold {
            if highLoadStart == nil {
                highLoadStart = .now
            }
            minutesAtHighLoad = Int(Date.now.timeIntervalSince(highLoadStart!) / 60)
        } else {
            highLoadStart = nil
            minutesAtHighLoad = 0
        }
    }

    private func generateSuggestion() -> String {
        if isCalibrating {
            let remaining = Int((ReflexConstants.baselineCalibrationDuration - Date.now.timeIntervalSince(calibrationStart)) / 60)
            return "Calibrating your baseline... \(max(0, remaining)) min remaining"
        }

        if minutesAtHighLoad >= 20 {
            return "⚠️ You've been overloaded for \(minutesAtHighLoad) min. Take a real break — walk, stretch, breathe."
        } else if minutesAtHighLoad >= 10 {
            return "🔴 High load sustained for \(minutesAtHighLoad) min. A short break will boost your performance."
        } else if minutesAtHighLoad >= 5 {
            return "🟠 Your cognitive load has been elevated. Consider pausing soon."
        }

        return loadLevel.suggestion
    }

    func createSnapshot() -> BehaviorSnapshot {
        let typing = keystrokeAnalyzer.metrics
        let mouse = mouseAnalyzer.metrics
        let appSwitch = appSwitchMonitor.metrics
        let elapsed = max(Date.now.timeIntervalSince(calibrationStart), 1)

        return BehaviorSnapshot(
            typingIntervalMean: typing.averageInterval,
            typingIntervalCV: typing.coefficientOfVariation,
            backspaceRatio: typing.backspaceRatio,
            pauseFrequency: typing.pauseFrequency,
            mouseJitter: mouse.velocityVariance,
            mouseIdleRatio: mouse.idleTime / elapsed,
            scrollDirectionChanges: Double(mouse.scrollDirectionChanges),
            appSwitchRate: appSwitch.switchesPerMinute,
            uniqueApps: Double(appSwitch.uniqueAppsInWindow),
            rapidSwitchBursts: Double(appSwitch.rapidSwitchBursts),
            timestamp: .now
        )
    }

    // MARK: - Baseline Calibration

    private func finalizeCalibration() {
        guard !calibrationSamples.isEmpty else { return }

        let avgTypingCV = calibrationSamples.map(\.typingIntervalCV).average
        let avgBackspace = calibrationSamples.map(\.backspaceRatio).average
        let avgJitter = calibrationSamples.map(\.mouseJitter).average
        let avgSwitchRate = calibrationSamples.map(\.appSwitchRate).average
        let avgTypingMean = calibrationSamples.map(\.typingIntervalMean).average

        baseline = BehaviorBaseline(
            typingIntervalMean: avgTypingMean,
            typingIntervalCV: avgTypingCV,
            backspaceRatio: avgBackspace,
            mouseJitter: avgJitter,
            appSwitchRate: avgSwitchRate
        )

        isCalibrating = false
        saveBaseline()
    }

    private func saveBaseline() {
        guard let baseline = baseline else { return }
        let url = getBaselineURL()
        do {
            let data = try JSONEncoder().encode(baseline)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
        } catch {
            print("Failed to save baseline: \(error)")
        }
    }

    private func loadBaseline() {
        let url = getBaselineURL()
        guard let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode(BehaviorBaseline.self, from: data) else {
            return
        }
        baseline = saved
        isCalibrating = false
    }

    private func getBaselineURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent(ReflexConstants.appSupportDirectory)
            .appendingPathComponent(ReflexConstants.baselineFileName)
    }

    func reset() {
        currentScore = 0
        smoothedScore = 0
        loadLevel = .flow
        loadHistory.removeAll()
        highLoadStart = nil
        minutesAtHighLoad = 0
        baseline = nil
        isCalibrating = true
        calibrationStart = .now
        calibrationSamples.removeAll()
    }

    deinit {
        updateTimer?.invalidate()
    }
}
