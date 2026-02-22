import SwiftUI
import AppKit

// MARK: - Break Overlay Window Controller

@MainActor
class BreakOverlayWindowController: ObservableObject {
    private var panel: NSPanel?
    private var spaceChangeObserver: Any?
    @Published var breakState: BreakState = .active(remaining: 300, total: 300)
    @Published var breathingEnabled: Bool = true

    enum BreakState {
        case active(remaining: TimeInterval, total: TimeInterval)
        case completed
        case skipped
    }

    func showBreakCountdown(duration: TimeInterval = 300, breathing: Bool = true) {
        breathingEnabled = breathing
        breakState = .active(remaining: duration, total: duration)
        if panel == nil { presentWindow() }
    }

    func updateCountdown(remaining: TimeInterval, total: TimeInterval) {
        breakState = .active(remaining: remaining, total: total)
    }

    func showCompleted() {
        breakState = .completed
    }

    func showSkipMessage() {
        breakState = .skipped
        presentWindow()
    }

    private func presentWindow() {
        if panel != nil { dismiss() }

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        let p = NSPanel(
            contentRect: screenFrame,
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        p.isFloatingPanel = true
        p.worksWhenModal = true
        p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.isMovable = false
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.ignoresMouseEvents = false
        p.hidesOnDeactivate = false
        p.appearance = NSAppearance(named: .darkAqua)

        let overlayView = BreakOverlayFullscreen(controller: self)
        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.frame = screenFrame
        hostingView.autoresizingMask = [.width, .height]

        p.contentView = hostingView
        p.setFrame(screenFrame, display: true)

        // Fade in
        p.alphaValue = 0
        p.orderFrontRegardless()

        // Monitor space changes to stay on top even in fullscreen spaces
        spaceChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let p = self.panel, p.isVisible else { return }
                p.orderFrontRegardless()
            }
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            p.animator().alphaValue = 1
        }

        self.panel = p
    }

    func dismiss() {
        if let observer = spaceChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            spaceChangeObserver = nil
        }
        guard let p = panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            p.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor [weak self] in
                p.orderOut(nil)
                self?.panel = nil
            }
        })
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }
}

// MARK: - Fullscreen Overlay View

struct BreakOverlayFullscreen: View {
    @ObservedObject var controller: BreakOverlayWindowController

    var body: some View {
        ZStack {
            // Dark translucent background
            Color.black.opacity(0.78)
                .ignoresSafeArea()

            // Subtle animated mesh in the background
            BreakBackgroundMesh()
                .opacity(0.3)
                .ignoresSafeArea()

            // Content
            switch controller.breakState {
            case .active(let remaining, let total):
                if controller.breathingEnabled {
                    BreakActiveView(remaining: remaining, total: total)
                } else {
                    BreakActiveTimerOnlyView(remaining: remaining, total: total)
                }
            case .completed:
                BreakCompletedView()
            case .skipped:
                BreakSkipMessageView()
            }
        }
    }
}

// MARK: - Skip Message (gentle encouragement)

struct BreakSkipMessageView: View {
    @State private var appear = false

    var body: some View {
        VStack(spacing: 40) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 110
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(appear ? 1.0 : 0.6)

                Image(systemName: "heart.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .pink.opacity(0.4), radius: 16)
                    .scaleEffect(appear ? 1.0 : 0.5)
            }

            VStack(spacing: 18) {
                Text("We understand")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(appear ? 1 : 0)

                Text("Sometimes you're in the zone, and that's okay.\nBut remember — your body and mind need rest too.")
                    .font(.system(size: 22, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)
                    .opacity(appear ? 1 : 0)

                Text("We'll check in again later.")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.4))
                    .opacity(appear ? 1 : 0)
            }

            // Click to dismiss hint
            Text("Click anywhere to dismiss")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.25))
                .opacity(appear ? 1 : 0)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            NotificationCenter.default.post(name: .dismissBreak, object: nil)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                appear = true
            }
        }
    }
}

// MARK: - Timer-Only Break View (no breathing exercise)

struct BreakActiveTimerOnlyView: View {
    let remaining: TimeInterval
    let total: TimeInterval

    var progress: Double {
        guard total > 0 else { return 0 }
        return 1.0 - (remaining / total)
    }

    var body: some View {
        VStack(spacing: 48) {
            // Large progress ring with big timer
            ZStack {
                // Outer ring track
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 10)
                    .frame(width: 400, height: 400)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.green, .mint, .teal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 400, height: 400)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                // Subtle glow behind timer
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.green.opacity(0.08), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 190
                        )
                    )
                    .frame(width: 380, height: 380)

                VStack(spacing: 10) {
                    Text(remaining.formattedMinutesSeconds)
                        .font(.system(size: 96, weight: .ultraLight, design: .monospaced))
                        .foregroundColor(.white)
                    Text("remaining")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.35))
                }
            }

            Text("Take a moment. Stretch, hydrate, rest your eyes.")
                .font(.system(size: 22, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.4))

            // End break early
            Button(action: {
                NotificationCenter.default.post(name: .endBreakEarly, object: nil)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle")
                    Text("End Break Early")
                }
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
    }
}

// MARK: - Active Break (countdown + breathing exercise)

struct BreakActiveView: View {
    let remaining: TimeInterval
    let total: TimeInterval

    @State private var breathPhase: BreathPhase = .inhale
    @State private var breathScale: CGFloat = 0.6
    @State private var breathOpacity: Double = 0.3
    @State private var breathCycleTimer: Timer?

    enum BreathPhase: String {
        case inhale = "Breathe in..."
        case hold = "Hold..."
        case exhale = "Breathe out..."
    }

    var progress: Double {
        guard total > 0 else { return 0 }
        return 1.0 - (remaining / total)
    }

    var body: some View {
        VStack(spacing: 44) {
            // Breathing circle with progress ring
            ZStack {
                // Outer progress ring track
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 7)
                    .frame(width: 340, height: 340)

                // Outer progress ring fill
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.green, .mint, .teal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .frame(width: 340, height: 340)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                // Breathing orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .green.opacity(breathOpacity + 0.2),
                                .mint.opacity(breathOpacity),
                                .teal.opacity(breathOpacity * 0.5),
                                .clear
                            ],
                            center: .center,
                            startRadius: 15,
                            endRadius: 150
                        )
                    )
                    .frame(width: 280, height: 280)
                    .scaleEffect(breathScale)

                // Time remaining
                VStack(spacing: 8) {
                    Text(remaining.formattedMinutesSeconds)
                        .font(.system(size: 68, weight: .ultraLight, design: .monospaced))
                        .foregroundColor(.white)
                    Text("remaining")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.35))
                }
            }

            // Breathing instruction
            Text(breathPhase.rawValue)
                .font(.system(size: 32, weight: .medium, design: .rounded))
                .foregroundColor(.mint.opacity(0.9))
                .contentTransition(.interpolate)
                .animation(.easeInOut(duration: 0.5), value: breathPhase)

            Text("Follow the circle. Let your mind rest.")
                .font(.system(size: 20, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.35))

            // End break early
            Button(action: {
                NotificationCenter.default.post(name: .endBreakEarly, object: nil)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle")
                    Text("End Break Early")
                }
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
        }
        .onAppear { startBreathingCycle() }
        .onDisappear { breathCycleTimer?.invalidate() }
    }

    private func startBreathingCycle() {
        func cycle() {
            // Inhale (4s)
            breathPhase = .inhale
            withAnimation(.easeInOut(duration: 4.0)) {
                breathScale = 1.0
                breathOpacity = 0.6
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                // Hold (4s)
                breathPhase = .hold
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    // Exhale (4s)
                    breathPhase = .exhale
                    withAnimation(.easeInOut(duration: 4.0)) {
                        breathScale = 0.6
                        breathOpacity = 0.3
                    }
                }
            }
        }

        cycle()
        breathCycleTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: true) { _ in
            Task { @MainActor in cycle() }
        }
    }
}

// MARK: - Break Completed

struct BreakCompletedView: View {
    @State private var appear = false

    var body: some View {
        VStack(spacing: 36) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.green.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 15,
                            endRadius: 100
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(appear ? 1.0 : 0.5)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 84))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(appear ? 1.0 : 0.3)
            }

            Text("Break Complete!")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .opacity(appear ? 1 : 0)

            Text("You're refreshed and ready to get back to work.")
                .font(.system(size: 22, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .opacity(appear ? 1 : 0)

            Button(action: {
                NotificationCenter.default.post(name: .dismissBreak, object: nil)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Back to Work")
                }
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 280, height: 56)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appear = true
            }
        }
    }
}

// MARK: - Animated Background

struct BreakBackgroundMesh: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let w = size.width
                let h = size.height

                for i in 0..<5 {
                    let fi = Double(i)
                    let cx = w * (0.3 + 0.4 * sin(t * 0.08 + fi * 1.2))
                    let cy = h * (0.3 + 0.4 * cos(t * 0.06 + fi * 0.9))
                    let r = min(w, h) * (0.18 + 0.06 * sin(t * 0.1 + fi))

                    let gradient = Gradient(colors: [
                        Color.green.opacity(0.12),
                        Color.mint.opacity(0.06),
                        Color.clear
                    ])

                    let shading = GraphicsContext.Shading.radialGradient(
                        gradient,
                        center: CGPoint(x: cx, y: cy),
                        startRadius: 0,
                        endRadius: r
                    )

                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: cx - r, y: cy - r,
                            width: r * 2, height: r * 2
                        )),
                        with: shading
                    )
                }
            }
        }
    }
}
