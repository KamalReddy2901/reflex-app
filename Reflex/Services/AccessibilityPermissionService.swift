import Foundation
import AppKit
import ApplicationServices
import Combine

@MainActor
class AccessibilityPermissionService: ObservableObject {
    @Published var isGranted: Bool = false
    @Published var hasBeenPrompted: Bool = false

    private var pollTimer: Timer?

    init() {
        checkPermission()
        startPolling()
    }

    func checkPermission() {
        isGranted = AXIsProcessTrusted()
    }

    func requestPermission() {
        hasBeenPrompted = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        isGranted = trusted
    }

    func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let wasGranted = self.isGranted
                self.checkPermission()
                // Once permission is granted, switch to a much slower poll
                // (every 30s) just to detect revocation, instead of every 2s.
                if !wasGranted && self.isGranted {
                    self.pollTimer?.invalidate()
                    self.pollTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                        Task { @MainActor in
                            self?.checkPermission()
                        }
                    }
                }
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    deinit {
        pollTimer?.invalidate()
    }
}
