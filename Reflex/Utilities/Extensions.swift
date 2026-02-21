import SwiftUI

// MARK: - View Extensions

extension View {
    func glassMorphic(cornerRadius: CGFloat = ReflexConstants.cardCornerRadius) -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.1), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
    }

    func glassButton() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Color Extensions

extension Color {
    static let reflexPurple = Color(red: 0.45, green: 0.30, blue: 0.90)
    static let reflexBlue = Color(red: 0.25, green: 0.50, blue: 0.95)
    static let reflexTeal = Color(red: 0.15, green: 0.70, blue: 0.75)
    static let reflexPink = Color(red: 0.90, green: 0.30, blue: 0.55)
    static let reflexDark = Color(red: 0.08, green: 0.06, blue: 0.15)

    static func loadColor(for score: Int) -> Color {
        switch score {
        case 0...25: return .green
        case 26...50: return .yellow
        case 51...75: return .orange
        default: return .red
        }
    }

    static func loadGradient(for score: Int) -> LinearGradient {
        let level = CognitiveLoadLevel.from(score: score)
        switch level {
        case .flow:
            return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
        case .moderate:
            return LinearGradient(colors: [.yellow, .green], startPoint: .leading, endPoint: .trailing)
        case .elevated:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        case .overloaded:
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        }
    }
}

// MARK: - Date Extensions

extension Date {
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }

    var relativeDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}

// MARK: - Double Extensions

extension Double {
    var formattedScore: String {
        String(format: "%.0f", self)
    }

    var formattedPercent: String {
        String(format: "%.1f%%", self * 100)
    }

    var formattedDuration: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        }
        return String(format: "%ds", seconds)
    }
}

// MARK: - Array Extensions

extension Array where Element: BinaryFloatingPoint {
    var average: Double {
        guard !isEmpty else { return 0 }
        return Double(reduce(0, +)) / Double(count)
    }

    var standardDeviation: Double {
        guard count > 1 else { return 0 }
        let avg = average
        let squaredDiffs = map { (Double($0) - avg) * (Double($0) - avg) }
        return sqrt(squaredDiffs.reduce(0, +) / Double(count - 1))
    }
}
