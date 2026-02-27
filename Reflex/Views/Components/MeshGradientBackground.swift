import SwiftUI

struct MeshGradientBackground: View {
    var intensity: Double = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    SIMD2<Float>(0.0, 0.0),
                    SIMD2<Float>(0.5, 0.0),
                    SIMD2<Float>(1.0, 0.0),

                    SIMD2<Float>(0.0, 0.5 + Float(sin(time * 0.3) * 0.1)),
                    SIMD2<Float>(
                        0.5 + Float(cos(time * 0.5) * 0.15),
                        0.5 + Float(sin(time * 0.4) * 0.15)
                    ),
                    SIMD2<Float>(1.0, 0.5 + Float(cos(time * 0.35) * 0.1)),

                    SIMD2<Float>(0.0, 1.0),
                    SIMD2<Float>(0.5, 1.0),
                    SIMD2<Float>(1.0, 1.0),
                ],
                colors: meshColors(at: time)
            )
        }
        .ignoresSafeArea()
    }

    private func meshColors(at time: Double) -> [Color] {
        let shift = sin(time * 0.2) * 0.08

        return [
            Color(red: max(0, 0.05 + shift), green: 0.02, blue: 0.15),
            Color(red: 0.08, green: max(0, 0.05 + shift), blue: 0.25),
            Color(red: 0.04, green: 0.08, blue: max(0, 0.18 + shift)),

            Color(red: max(0, 0.10 + shift), green: 0.04, blue: 0.30),
            Color(red: 0.15, green: max(0, 0.10 + shift * 0.5), blue: 0.40 * intensity),
            Color(red: 0.05, green: 0.15, blue: max(0, 0.35 + shift)),

            Color(red: 0.08, green: max(0, 0.03 + shift), blue: 0.20),
            Color(red: max(0, 0.12 + shift), green: 0.06, blue: 0.28),
            Color(red: 0.06, green: 0.10, blue: max(0, 0.22 + shift)),
        ]
    }
}

// MARK: - Subtle Gradient Background

struct SubtleGradientBackground: View {
    let colors: [Color]

    init(colors: [Color] = ReflexConstants.brandGradient) {
        self.colors = colors
    }

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
