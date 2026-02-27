import Foundation
import AppKit
import Combine

@MainActor
class EventMonitorService: ObservableObject {
    @Published var isMonitoring: Bool = false
    @Published var lastKeyEvent: Date?
    @Published var lastMouseEvent: Date?

    // Callbacks for analyzers
    var onKeyDown: ((Date) -> Void)?
    var onKeyUp: ((Date) -> Void)?
    var onBackspace: ((Date) -> Void)?
    var onMouseMoved: ((CGPoint, Date) -> Void)?
    var onScrollWheel: ((CGFloat, CGFloat, Date) -> Void)?
    var onMouseDown: ((Date) -> Void)?
    var onMouseUp: ((Date) -> Void)?

    private var globalKeyMonitor: Any?
    private var globalMouseMonitor: Any?
    private var globalScrollMonitor: Any?

    func startMonitoring() {
        guard !isMonitoring else { return }

        // Key events monitor
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged]
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyEvent(event)
            }
        }

        // Mouse movement monitor
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .leftMouseDragged]
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseEvent(event)
            }
        }

        // Scroll monitor
        globalScrollMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .scrollWheel
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleScrollEvent(event)
            }
        }

        isMonitoring = true
    }

    func stopMonitoring() {
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        if let monitor = globalScrollMonitor {
            NSEvent.removeMonitor(monitor)
            globalScrollMonitor = nil
        }
        isMonitoring = false
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let now = Date()
        lastKeyEvent = now

        switch event.type {
        case .keyDown:
            if event.keyCode == 51 {
                // Backspace: fire only onBackspace (which internally calls
                // recordKeystroke). Firing onKeyDown too would double-count
                // the keystroke and inject a zero-interval artifact into
                // the typing rhythm analysis.
                onBackspace?(now)
            } else {
                onKeyDown?(now)
            }
        case .keyUp:
            onKeyUp?(now)
        default:
            break
        }
    }

    private func handleMouseEvent(_ event: NSEvent) {
        let now = Date()
        lastMouseEvent = now

        switch event.type {
        case .mouseMoved, .leftMouseDragged:
            let location = NSEvent.mouseLocation
            onMouseMoved?(location, now)
        case .leftMouseDown, .rightMouseDown:
            onMouseDown?(now)
        case .leftMouseUp, .rightMouseUp:
            onMouseUp?(now)
        default:
            break
        }
    }

    private func handleScrollEvent(_ event: NSEvent) {
        let now = Date()
        lastMouseEvent = now
        onScrollWheel?(event.scrollingDeltaX, event.scrollingDeltaY, now)
    }

    deinit {
        if let monitor = globalKeyMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = globalMouseMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = globalScrollMonitor { NSEvent.removeMonitor(monitor) }
    }
}
