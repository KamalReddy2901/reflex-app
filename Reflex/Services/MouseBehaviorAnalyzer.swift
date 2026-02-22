import Foundation
import Combine

@MainActor
class MouseBehaviorAnalyzer: ObservableObject {
    @Published var metrics = MouseMetrics()

    private var velocities = RingBuffer<Double>(capacity: ReflexConstants.mouseWindowSize)
    private var lastPosition: CGPoint?
    private var lastMoveTime: Date?
    private var lastActivityTime: Date = .now
    private var scrollCount: Int = 0
    private var lastScrollDirection: CGFloat = 0
    private var directionChanges: Int = 0
    private var totalDistance: Double = 0
    private var windowStart: Date = .now
    private var idleAccumulator: TimeInterval = 0
    private let idleThreshold: TimeInterval = 5.0

    /// Windowed counters reset every 60 s so scroll frequency and direction-
    /// change metrics stay responsive instead of growing unboundedly.
    private var windowedScrollCount: Int = 0
    private var windowedDirectionChanges: Int = 0
    private var scrollWindowTimer: Timer?

    init() {
        scrollWindowTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.windowedScrollCount = 0
                self?.windowedDirectionChanges = 0
            }
        }
    }

    func recordMouseMove(position: CGPoint, at time: Date) {
        if let lastPos = lastPosition, let lastTime = lastMoveTime {
            let dx = Double(position.x - lastPos.x)
            let dy = Double(position.y - lastPos.y)
            let distance = sqrt(dx * dx + dy * dy)
            let dt = time.timeIntervalSince(lastTime)

            guard dt > 0.001 else { return }  // Ignore sub-millisecond events

            let velocity = distance / dt
            velocities.append(velocity)
            totalDistance += distance

            if dt > idleThreshold {
                idleAccumulator += dt
            }
        }

        lastPosition = position
        lastMoveTime = time
        lastActivityTime = time

        updateMetrics()
    }

    func recordScroll(deltaX: CGFloat, deltaY: CGFloat, at time: Date) {
        scrollCount += 1
        windowedScrollCount += 1
        lastActivityTime = time

        if deltaY != 0 {
            let currentDirection: CGFloat = deltaY > 0 ? 1 : -1
            if lastScrollDirection != 0 && currentDirection != lastScrollDirection {
                directionChanges += 1
                windowedDirectionChanges += 1
            }
            lastScrollDirection = currentDirection
        }

        updateMetrics()
    }

    private func updateMetrics() {
        let elapsed = Date.now.timeIntervalSince(windowStart)
        // Cap denominator at 5 minutes so scroll frequency stays responsive
        let windowSeconds = min(elapsed, ReflexConstants.appSwitchWindowSeconds)
        let minutesElapsed = max(windowSeconds / 60.0, 0.1)

        var currentIdle: TimeInterval = 0
        let timeSinceLastActivity = Date.now.timeIntervalSince(lastActivityTime)
        if timeSinceLastActivity > idleThreshold {
            currentIdle = timeSinceLastActivity
        }

        metrics.averageVelocity = velocities.mean
        metrics.velocityVariance = velocities.variance
        metrics.jitterLevel = MouseMetrics.JitterLevel.from(variance: velocities.variance)
        metrics.idleTime = idleAccumulator + currentIdle
        // Use windowed counters so metrics don't inflate over long sessions
        metrics.scrollFrequency = Double(windowedScrollCount) / minutesElapsed
        metrics.scrollDirectionChanges = windowedDirectionChanges
        metrics.totalDistance = totalDistance
        metrics.timestamp = .now
    }

    func reset() {
        velocities.clear()
        lastPosition = nil
        lastMoveTime = nil
        scrollCount = 0
        windowedScrollCount = 0
        lastScrollDirection = 0
        directionChanges = 0
        windowedDirectionChanges = 0
        totalDistance = 0
        idleAccumulator = 0
        windowStart = .now
        metrics = MouseMetrics()
    }

    deinit {
        scrollWindowTimer?.invalidate()
    }
}
