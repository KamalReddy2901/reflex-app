import SwiftUI

struct CognitiveLoadRing: View {
    let score: Int
    let size: CGFloat
    let lineWidth: CGFloat
    let showLabel: Bool

    @State private var animatedProgress: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: CGFloat = 0.3

    init(score: Int, size: CGFloat = 140, lineWidth: CGFloat = 12, showLabel: Bool = true) {
        self.score = score
        self.size = size
        self.lineWidth = lineWidth
        self.showLabel = showLabel
    }

    private var progress: CGFloat {
        CGFloat(score) / 100.0
    }

    private var level: CognitiveLoadLevel {
        CognitiveLoadLevel.from(score: score)
    }

    private var ringGradient: AngularGradient {
        let colors: [Color]
        switch level {
        case .flow:
            colors = [.green.opacity(0.6), .mint, .green]
        case .moderate:
            colors = [.green.opacity(0.6), .yellow, .green.opacity(0.6)]
        case .elevated:
            colors = [.yellow.opacity(0.6), .orange, .yellow.opacity(0.6)]
        case .overloaded:
            colors = [.orange.opacity(0.6), .red, .orange.opacity(0.6)]
        }
        return AngularGradient(colors: colors, center: .center, startAngle: .degrees(-90), endAngle: .degrees(270))
    }

    var body: some View {
        ZStack {
            // Outer glow for high load
            if score > 60 {
                Circle()
                    .fill(level.color.opacity(0.15))
                    .frame(width: size + 20, height: size + 20)
                    .blur(radius: 15)
                    .scaleEffect(pulseScale)
            }

            // Background track
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    ringGradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .shadow(color: level.color.opacity(0.5), radius: 8, x: 0, y: 0)

            // Center content
            if showLabel {
                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())

                    Text(level.label)
                        .font(.system(size: size * 0.09, weight: .medium, design: .rounded))
                        .foregroundColor(level.color)
                        .textCase(.uppercase)
                        .tracking(1.5)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animatedProgress = progress
            }

            if score > 60 {
                withAnimation(
                    .easeInOut(duration: ReflexConstants.pulseAnimationDuration)
                        .repeatForever(autoreverses: true)
                ) {
                    pulseScale = 1.08
                    glowOpacity = 0.5
                }
            }
        }
        .onChange(of: score) { _, newValue in
            withAnimation(.easeInOut(duration: 0.6)) {
                animatedProgress = CGFloat(newValue) / 100.0
            }
        }
    }
}

// MARK: - Mini Load Ring

struct MiniLoadRing: View {
    let score: Int
    let size: CGFloat

    init(score: Int, size: CGFloat = 24) {
        self.score = score
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 3)

            Circle()
                .trim(from: 0, to: CGFloat(score) / 100.0)
                .stroke(
                    Color.loadColor(for: score),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}
