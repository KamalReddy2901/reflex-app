import Foundation

struct TypingMetrics {
    var averageInterval: TimeInterval = 0
    var intervalVariance: Double = 0
    var coefficientOfVariation: Double = 0
    var backspaceRatio: Double = 0
    var pauseFrequency: Double = 0
    var wordsPerMinute: Double = 0        // Overall WPM (includes idle time)
    var burstWordsPerMinute: Double = 0   // Raw WPM during active typing only
    var totalKeystrokes: Int = 0
    var recentKeystrokes: Int = 0
    var timestamp: Date = .now
}

struct MouseMetrics {
    var averageVelocity: Double = 0
    var velocityVariance: Double = 0
    var jitterLevel: JitterLevel = .calm
    var idleTime: TimeInterval = 0
    var scrollFrequency: Double = 0
    var scrollDirectionChanges: Int = 0
    var totalDistance: Double = 0
    var timestamp: Date = .now

    enum JitterLevel: String {
        case calm = "Calm"
        case normal = "Normal"
        case jittery = "Jittery"
        case erratic = "Erratic"

        static func from(variance: Double) -> JitterLevel {
            switch variance {
            case ..<50_000: return .calm
            case 50_000..<200_000: return .normal
            case 200_000..<600_000: return .jittery
            default: return .erratic
            }
        }
    }
}

struct AppSwitchMetrics {
    var switchesPerMinute: Double = 0
    var uniqueAppsInWindow: Int = 0
    var rapidSwitchBursts: Int = 0
    var currentApp: String = ""
    var timeInCurrentApp: TimeInterval = 0
    var timestamp: Date = .now
}

struct BehaviorSnapshot: Codable {
    var typingIntervalMean: Double
    var typingIntervalCV: Double
    var backspaceRatio: Double
    var pauseFrequency: Double
    var mouseJitter: Double
    var mouseIdleRatio: Double
    var scrollDirectionChanges: Double
    var appSwitchRate: Double
    var uniqueApps: Double
    var rapidSwitchBursts: Double
    var timestamp: Date

    static var empty: BehaviorSnapshot {
        BehaviorSnapshot(
            typingIntervalMean: 0, typingIntervalCV: 0,
            backspaceRatio: 0, pauseFrequency: 0,
            mouseJitter: 0, mouseIdleRatio: 0,
            scrollDirectionChanges: 0, appSwitchRate: 0,
            uniqueApps: 0, rapidSwitchBursts: 0,
            timestamp: .now
        )
    }
}
