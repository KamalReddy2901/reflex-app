import SwiftUI

enum CognitiveLoadLevel: String, CaseIterable, Codable {
    case flow
    case moderate
    case elevated
    case overloaded

    var label: String {
        switch self {
        case .flow: return "Flow"
        case .moderate: return "Moderate"
        case .elevated: return "Elevated"
        case .overloaded: return "Overloaded"
        }
    }

    var emoji: String {
        switch self {
        case .flow: return "🟢"
        case .moderate: return "🟡"
        case .elevated: return "🟠"
        case .overloaded: return "🔴"
        }
    }

    var color: Color {
        switch self {
        case .flow: return .green
        case .moderate: return .yellow
        case .elevated: return .orange
        case .overloaded: return .red
        }
    }

    var suggestion: String {
        switch self {
        case .flow: return "You're in the zone — keep going!"
        case .moderate: return "Doing well. Stay hydrated and focused."
        case .elevated: return "Consider a short break soon."
        case .overloaded: return "Take a break now. You've earned it."
        }
    }

    var scoreRange: ClosedRange<Int> {
        switch self {
        case .flow: return 0...25
        case .moderate: return 26...50
        case .elevated: return 51...75
        case .overloaded: return 76...100
        }
    }

    static func from(score: Int) -> CognitiveLoadLevel {
        let clamped = max(0, min(100, score))
        switch clamped {
        case 0...25: return .flow
        case 26...50: return .moderate
        case 51...75: return .elevated
        default: return .overloaded
        }
    }
}
