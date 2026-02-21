import SwiftUI
import AppKit

// MARK: - Break Notification Popup Controller
// Top-right notification card with action buttons (DeskRest-style)

@MainActor
class BreakNotificationPopupController: ObservableObject {
    private var panel: NSPanel?
    private var spaceChangeObserver: Any?
    @Published var loadScore: Int = 0
    @Published var minutesAtHighLoad: Int = 0
    @Published var countdownSeconds: Int = 30

    private let popupWidth: CGFloat = 320
    private let popupHeight: CGFloat = 200

    func show(loadScore: Int, minutesAtHighLoad: Int, countdown: Int = 30) {
        if panel != nil { dismiss() }

        self.loadScore = loadScore
        self.minutesAtHighLoad = minutesAtHighLoad
        self.countdownSeconds = countdown

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        let x = screenFrame.maxX - popupWidth - 16
        let y = screenFrame.maxY - popupHeight - 16

        let frame = NSRect(x: x, y: y, width: popupWidth, height: popupHeight)
        let p = NSPanel(
            contentRect: frame,
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
        p.hasShadow = true
        p.hidesOnDeactivate = false
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden

        let contentView = BreakNotificationPopupView(controller: self)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(origin: .zero, size: frame.size)
        hostingView.autoresizingMask = [.width, .height]
        p.contentView = hostingView

        // Slide in from right
        let startFrame = NSRect(x: screenFrame.maxX + 10, y: y, width: popupWidth, height: popupHeight)
        p.setFrame(startFrame, display: false)
        p.alphaValue = 0
        p.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            p.animator().setFrame(frame, display: true)
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
    }

    func updateCountdown(_ seconds: Int) {
        countdownSeconds = seconds
    }

    func dismiss() {
        if let observer = spaceChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            spaceChangeObserver = nil
        }
        guard let win = panel else { return }
        guard let screen = NSScreen.main else {
            win.orderOut(nil)
            panel = nil
            return
        }

        let screenFrame = screen.visibleFrame
        let offscreen = NSRect(
            x: screenFrame.maxX + 10,
            y: win.frame.origin.y,
            width: popupWidth,
            height: popupHeight
        )

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            win.animator().setFrame(offscreen, display: true)
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

// MARK: - Popup View

struct BreakNotificationPopupView: View {
    @ObservedObject var controller: BreakNotificationPopupController

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Time for a Break")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(breakSubtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                // Countdown badge
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 36, height: 36)

                    Text("\(controller.countdownSeconds)s")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.mint)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .background(Color.white.opacity(0.1))

            // Action buttons
            VStack(spacing: 6) {
                // Duration choices (start break with chosen duration)
                HStack(spacing: 6) {
                    durationButton(minutes: 2)
                    durationButton(minutes: 5)
                    durationButton(minutes: 10)
                }

                // Snooze & skip row
                HStack(spacing: 6) {
                    snoozeButton(minutes: 1, label: "+1 min")
                    snoozeButton(minutes: 5, label: "+5 min")
                    snoozeButton(minutes: 10, label: "+10 min")

                    Button(action: {
                        NotificationCenter.default.post(name: .skipBreak, object: nil)
                    }) {
                        Text("Skip")
                            .font(.system(size: 11, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.25))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: ReflexConstants.cardCornerRadius)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ReflexConstants.cardCornerRadius)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: ReflexConstants.cardCornerRadius))
    }

    private var breakSubtitle: String {
        if controller.minutesAtHighLoad > 0 {
            return "\(controller.minutesAtHighLoad) min under high load"
        }
        return "Your mind deserves a pause"
    }

    private func durationButton(minutes: Int) -> some View {
        Button(action: {
            NotificationCenter.default.post(
                name: .takeBreak,
                object: nil,
                userInfo: ["durationMinutes": minutes]
            )
        }) {
            HStack(spacing: 4) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 10))
                Text("\(minutes) min")
            }
            .font(.system(size: 12, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 32)
        }
        .buttonStyle(.borderedProminent)
        .tint(minutes == 5 ? .green : .green.opacity(0.7))
    }

    private func snoozeButton(minutes: Int, label: String) -> some View {
        Button(action: {
            NotificationCenter.default.post(
                name: .snoozeBreak,
                object: nil,
                userInfo: ["minutes": minutes]
            )
        }) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 28)
        }
        .buttonStyle(.bordered)
        .tint(.white.opacity(0.3))
    }
}
