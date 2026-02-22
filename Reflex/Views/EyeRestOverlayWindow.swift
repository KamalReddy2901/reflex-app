import SwiftUI
import AppKit

// MARK: - Eye Rest Overlay Window Controller

@MainActor
class EyeRestOverlayWindowController: ObservableObject {
    private var panel: NSPanel?
    private var spaceChangeObserver: Any?
    @Published var state: EyeRestState = .active(remaining: 20, total: 20)

    enum EyeRestState {
        case active(remaining: TimeInterval, total: TimeInterval)
        case completed
    }

    func show(duration: TimeInterval = 20) {
        state = .active(remaining: duration, total: duration)
        if panel == nil { presentWindow() }
    }

    func updateCountdown(remaining: TimeInterval) {
        let total: TimeInterval
        if case .active(_, let t) = state { total = t } else { total = ReflexConstants.eyeRestDuration }
        state = .active(remaining: remaining, total: total)
    }

    func showCompleted() {
        state = .completed
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

        let overlayView = EyeRestOverlayView(controller: self)
        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.frame = screenFrame
        hostingView.autoresizingMask = [.width, .height]

        p.contentView = hostingView
        p.setFrame(screenFrame, display: true)

        p.alphaValue = 0
        p.orderFrontRegardless()

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

// MARK: - Eye Rest Overlay View

struct EyeRestOverlayView: View {
    @ObservedObject var controller: EyeRestOverlayWindowController

    var body: some View {
        ZStack {
            // Dark background
            Color.black.opacity(0.82)
                .ignoresSafeArea()

            // Subtle animated background
            EyeRestBackground()
                .opacity(0.3)
                .ignoresSafeArea()

            switch controller.state {
            case .active(let remaining, let total):
                EyeRestActiveView(remaining: remaining, total: total)
            case .completed:
                EyeRestCompletedView()
            }
        }
    }
}

// MARK: - Active Eye Rest View

struct EyeRestActiveView: View {
    let remaining: TimeInterval
    let total: TimeInterval

    @State private var pulseScale: CGFloat = 1.0

    var progress: Double {
        guard total > 0 else { return 0 }
        return 1.0 - (remaining / total)
    }

    var body: some View {
        VStack(spacing: 48) {
            // Eye icon with pulse
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.15), .cyan.opacity(0.05), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)
                    .scaleEffect(pulseScale)

                // Progress ring
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 8)
                    .frame(width: 220, height: 220)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .cyan, .teal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                VStack(spacing: 12) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .blue.opacity(0.4), radius: 12)

                    Text("\(Int(remaining))")
                        .font(.system(size: 64, weight: .ultraLight, design: .monospaced))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.3), value: remaining)
                }
            }

            VStack(spacing: 16) {
                Text("Give Rest to Your Eyes")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Look at something 20 feet away.\nYour eyes will thank you.")
                    .font(.system(size: 22, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            // Skip button
            Button(action: {
                NotificationCenter.default.post(name: .skipEyeRest, object: nil)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle")
                    Text("Skip")
                }
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.08
            }
        }
    }
}

// MARK: - Eye Rest Completed View

struct EyeRestCompletedView: View {
    @State private var appear = false

    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 90
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(appear ? 1.0 : 0.5)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(appear ? 1.0 : 0.3)
            }

            Text("Eyes Refreshed!")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .opacity(appear ? 1 : 0)

            Text("Great job. Your eyes appreciate the break.")
                .font(.system(size: 20, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .opacity(appear ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            NotificationCenter.default.post(name: .dismissEyeRest, object: nil)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appear = true
            }
        }
    }
}

// MARK: - Eye Rest Background Animation

struct EyeRestBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let w = size.width
                let h = size.height

                for i in 0..<4 {
                    let fi = Double(i)
                    let cx = w * (0.3 + 0.4 * sin(t * 0.06 + fi * 1.5))
                    let cy = h * (0.3 + 0.4 * cos(t * 0.05 + fi * 1.1))
                    let r = min(w, h) * (0.15 + 0.05 * sin(t * 0.08 + fi))

                    let gradient = Gradient(colors: [
                        Color.blue.opacity(0.10),
                        Color.cyan.opacity(0.05),
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
