import SwiftUI
import AppKit

// MARK: - Cursor Follower Window Controller
// A small circular countdown that follows the mouse cursor (DeskRest-style)

@MainActor
class CursorFollowerWindowController: ObservableObject {
    private var panel: NSPanel?
    private var displayTimer: DispatchSourceTimer?
    private var mouseEventMonitor: Any?
    private var localMouseEventMonitor: Any?
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

        // Event-driven cursor tracking: update position on every mouse move
        // for zero-latency following (replaces timer-based polling)
        mouseEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let p = self.panel else { return }
                self.positionNearCursor(p)
            }
        }
        localMouseEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        ) { [weak self] event in
            Task { @MainActor in
                guard let self = self, let p = self.panel else { return }
                self.positionNearCursor(p)
            }
            return event
        }

        // Fallback display-linked timer at ~60fps to catch cases where
        // mouse events don't fire (e.g., mouse stationary but user scrolled
        // the screen or switched spaces)
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(16))
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self = self, let p = self.panel else { return }
                self.positionNearCursor(p)
            }
        }
        timer.resume()
        self.displayTimer = timer
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
        displayTimer?.cancel()
        displayTimer = nil
        if let monitor = mouseEventMonitor {
            NSEvent.removeMonitor(monitor)
            mouseEventMonitor = nil
        }
        if let monitor = localMouseEventMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseEventMonitor = nil
        }
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
