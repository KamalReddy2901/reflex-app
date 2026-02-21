import SwiftUI

struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    let trend: Trend
    let sparklineData: [Double]
    let description: String?

    enum Trend {
        case up, down, stable

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "arrow.right"
            }
        }

        var color: Color {
            switch self {
            case .up: return .orange
            case .down: return .green
            case .stable: return .blue
            }
        }
    }

    init(title: String, value: String, icon: String, trend: Trend = .stable, sparklineData: [Double] = [], description: String? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.trend = trend
        self.sparklineData = sparklineData
        self.description = description
    }

    var body: some View {
        GlassMorphicCard(tintColor: .white.opacity(0.03)) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))

                    Text(title)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))

                    Spacer()

                    Image(systemName: trend.icon)
                        .font(.caption2)
                        .foregroundColor(trend.color)
                }

                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                if let description = description {
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }

                if !sparklineData.isEmpty {
                    SparklineView(data: sparklineData, color: trend.color)
                        .frame(height: 24)
                }
            }
        }
    }
}

// MARK: - Sparkline View

struct SparklineView: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let maxVal = data.max() ?? 1
            let minVal = data.min() ?? 0
            let range = maxVal - minVal
            let normalizedData = data.map { range > 0 ? ($0 - minVal) / range : 0.5 }

            ZStack {
                // Line
                Path { path in
                    guard normalizedData.count > 1 else { return }
                    let stepX = geometry.size.width / CGFloat(normalizedData.count - 1)

                    for (index, value) in normalizedData.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = geometry.size.height * (1 - CGFloat(value))
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color.opacity(0.8), lineWidth: 1.5)

                // Fill
                Path { path in
                    guard normalizedData.count > 1 else { return }
                    let stepX = geometry.size.width / CGFloat(normalizedData.count - 1)

                    path.move(to: CGPoint(x: 0, y: geometry.size.height))

                    for (index, value) in normalizedData.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = geometry.size.height * (1 - CGFloat(value))
                        path.addLine(to: CGPoint(x: x, y: y))
                    }

                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.2), color.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }
}
