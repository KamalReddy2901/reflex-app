import SwiftUI

/// A small wrapper view used as the menu bar label.
/// Its purpose is to hold `@Environment(\.openWindow)` so it can
/// programmatically open the onboarding window on first launch.
struct OnboardingTriggerView: View {
    @Binding var hasCompletedOnboarding: Bool
    var loadEngine: CognitiveLoadEngine?
    @Binding var isInitialized: Bool
    var initialize: () -> Void

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "brain.head.profile")
            if let engine = loadEngine {
                ObservingScoreLabel(engine: engine)
            }
        }
        .onAppear {
            initialize()
            if !hasCompletedOnboarding {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    openWindow(id: "onboarding")
                }
            }
        }
    }
}

/// Separate view that uses `@ObservedObject` so SwiftUI
/// re-renders when `currentScore` changes.
private struct ObservingScoreLabel: View {
    @ObservedObject var engine: CognitiveLoadEngine

    var body: some View {
        Text("\(engine.currentScore)")
            .font(.caption)
            .monospacedDigit()
    }
}
