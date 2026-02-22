import SwiftUI
import AppKit

// MARK: - Cursor Follower Window Controller
// A small circular countdown that follows the mouse cursor (DeskRest-style)

@MainActor
class CursorFollowerWindowController: ObservableObject {
    private var panel: NSPanel?
    private var trackingTimer: Timer?
    private var spaceChangeObserver: Any?
    @Published var secondsRemaining: Int = 30
    @Published var totalSeconds: Int = 30

    private let followerSize: CGFloat = 56

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(secondsRemaining) / Double(totalSeconds))
    }

    func show(countdownSeconds: Int = 30) {
        if panel != nil { dismiss() }

        totalSeconds = countdownSeconds
        secondsRemaining = countdownSeconds

        let frame = NSRect(x: 0, y: 0, width: followerSize, height: followerSize)
        let p = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
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
        p.hidesOnDeactivate = false
        p.ignoresMouseEvents = true // Click-through!
        p.appearance = NSAppearance(named: .darkAqua)

        let contentView = CursorFollowerView(controller: self)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = frame
        hostingView.autoresizingMask = [.width, .height]
        p.contentView = hostingView

        // Position near cursor
        positionNearCursor(p)

        p.alphaValue = 0
        p.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            p.animator().alphaValue = 1
        }

        self.panel = p

        // Stay on top when switching to fullscreen spaces
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

        // Track cursor position
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let p = self.panel else { return }
                self.positionNearCursor(p)
            }
        }
    }

    func tick() {
        guard secondsRemaining > 0 else { return }
        secondsRemaining -= 1
    }

    private func positionNearCursor(_ p: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        // Offset: 24px to the right and 24px above cursor
        let x = mouseLocation.x + 24
        let y = mouseLocation.y + 24
        p.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func dismiss() {
        trackingTimer?.invalidate()
        trackingTimer = nil
        if let observer = spaceChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            spaceChangeObserver = nil
        }
        guard let win = panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            win.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor [weak self] in
                win.orderOut(nil)
                self?.panel = nil
            }
        })
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }
}

// MARK: - Cursor Follower SwiftUI View

struct CursorFollowerView: View {
    @ObservedObject var controller: CursorFollowerWindowController

    var body: some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 3)

            // Progress ring
            Circle()
                .trim(from: 0, to: controller.progress)
                .stroke(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: controller.progress)

            // Background blur circle
            Circle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)

            // Seconds text
            Text("\(controller.secondsRemaining)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
        }
        .frame(width: 48, height: 48)
        .padding(4)
    }
}
