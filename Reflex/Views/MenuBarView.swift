import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var loadEngine: CognitiveLoadEngine
    @EnvironmentObject var permissionService: AccessibilityPermissionService
    @EnvironmentObject var breakService: BreakReminderService
    @EnvironmentObject var keystrokeAnalyzer: KeystrokeAnalyzer
    @EnvironmentObject var mouseAnalyzer: MouseBehaviorAnalyzer
    @EnvironmentObject var appSwitchMonitor: AppSwitchMonitor

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ZStack {
            MeshGradientBackground(intensity: Double(loadEngine.currentScore) / 100.0)

            if !permissionService.isGranted {
                compactPermissionView
            } else {
                mainStatusView
            }
        }
        .frame(width: ReflexConstants.menuBarPopoverWidth, height: ReflexConstants.menuBarPopoverHeight)
    }

    // MARK: - Main Status

    private var mainStatusView: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reflex")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Text(loadEngine.isCalibrating ? "Calibrating..." : "Monitoring")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))

                        if !loadEngine.isCalibrating {
                            Text("·")
                                .foregroundColor(.white.opacity(0.3))
                            Label(breakService.sessionDuration, systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }

                Spacer()

                GlassChip(
                    loadEngine.loadLevel.label,
                    icon: "brain.head.profile",
                    color: loadEngine.loadLevel.color
                )
            }
            .padding(.horizontal, 4)

            // Load Ring
            CognitiveLoadRing(score: loadEngine.currentScore, size: 90, lineWidth: 8)

            // Suggestion
            GlassMorphicCard(tintColor: loadEngine.loadLevel.color.opacity(0.08)) {
                HStack(spacing: 8) {
                    Image(systemName: suggestionIcon)
                        .foregroundColor(loadEngine.loadLevel.color)
                    Text(loadEngine.suggestion)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }

            // Focus & Break Summary
            HStack(spacing: 0) {
                miniStat(icon: "timer", label: "Focus", value: breakService.focusTimeFormatted)
                Spacer()
                miniStat(icon: "cup.and.saucer", label: "Breaks", value: "\(breakService.breaksTaken)")
                if let last = breakService.lastBreakTime {
                    Spacer()
                    miniStat(icon: "clock.arrow.circlepath", label: "Last break", value: timeSince(last))
                }
            }
            .padding(.horizontal, 4)

            // Metrics Grid — each tile opens the dashboard
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                Button { openDashboard(tab: .overview) } label: {
                    MetricTile(
                        title: "Typing",
                        value: String(format: "%.0f WPM", keystrokeAnalyzer.metrics.burstWordsPerMinute),
                        icon: "keyboard",
                        trend: typingTrend,
                        description: "Active typing speed"
                    )
                }
                .buttonStyle(.plain)

                Button { openDashboard(tab: .overview) } label: {
                    MetricTile(
                        title: "Errors",
                        value: String(format: "%.1f%%", keystrokeAnalyzer.metrics.backspaceRatio * 100),
                        icon: "delete.backward",
                        trend: errorTrend,
                        description: "Backspace ratio"
                    )
                }
                .buttonStyle(.plain)

                Button { openDashboard(tab: .overview) } label: {
                    MetricTile(
                        title: "Focus",
                        value: String(format: "%.1f/min", appSwitchMonitor.metrics.switchesPerMinute),
                        icon: "arrow.triangle.swap",
                        trend: focusTrend,
                        description: "Context switches / min"
                    )
                }
                .buttonStyle(.plain)

                Button { openDashboard(tab: .overview) } label: {
                    MetricTile(
                        title: "Mouse",
                        value: mouseAnalyzer.metrics.jitterLevel.rawValue,
                        icon: "computermouse",
                        trend: mouseTrend,
                        description: "Movement stability"
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Bottom Actions
            HStack(spacing: 8) {
                Button(action: {
                    activateAndOpenDashboard()
                }) {
                    Label("Dashboard", systemImage: "chart.bar.xaxis")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .glassButton()
                .buttonStyle(.plain)

                Spacer()

                Button(action: {
                    breakService.sendBreakReminder(loadScore: 80, minutesAtHighLoad: 15)
                }) {
                    Image(systemName: "bell.badge")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Test break overlay")

                Menu {
                    Button("2 minutes") { breakService.startBreak(durationMinutes: 2) }
                    Button("5 minutes") { breakService.startBreak(durationMinutes: 5) }
                    Button("10 minutes") { breakService.startBreak(durationMinutes: 10) }
                } label: {
                    Label("Take Break", systemImage: "cup.and.saucer")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .menuStyle(.borderlessButton)
                .glassButton()
            }

            // Breaks taken today
            if breakService.breaksTaken > 0 {
                HStack {
                    Spacer()
                    Text("\(breakService.breaksTaken) break\(breakService.breaksTaken == 1 ? "" : "s") taken today")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                }
            }

            // Quit
            HStack {
                Spacer()
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit Reflex")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.25))
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(16)
    }

    // MARK: - Permission View

    private var compactPermissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundColor(.reflexPurple)

            Text("Accessibility Access Required")
                .font(.headline)
                .foregroundColor(.white)

            Text("Reflex needs accessibility permissions to monitor your typing and mouse patterns. No personal data is recorded.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Button("Grant Access") {
                permissionService.requestPermission()
            }
            .buttonStyle(.borderedProminent)
            .tint(.reflexPurple)
        }
        .padding(24)
    }

    // MARK: - Computed Properties

    private var suggestionIcon: String {
        switch loadEngine.loadLevel {
        case .flow: return "checkmark.circle"
        case .moderate: return "info.circle"
        case .elevated: return "exclamationmark.triangle"
        case .overloaded: return "exclamationmark.octagon"
        }
    }

    private var typingTrend: MetricTile.Trend {
        keystrokeAnalyzer.metrics.coefficientOfVariation > 0.5 ? .up : .stable
    }

    private var errorTrend: MetricTile.Trend {
        keystrokeAnalyzer.metrics.backspaceRatio > 0.1 ? .up : .stable
    }

    private var focusTrend: MetricTile.Trend {
        appSwitchMonitor.metrics.switchesPerMinute > 4 ? .up : .stable
    }

    private var mouseTrend: MetricTile.Trend {
        let level = mouseAnalyzer.metrics.jitterLevel
        return (level == .jittery || level == .erratic) ? .up : .stable
    }

    // MARK: - Actions

    private func miniStat(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.35))
        }
    }

    private func timeSince(_ date: Date) -> String {
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        return "\(mins / 60)h ago"
    }

    private func openDashboard(tab: NavigationState.DashboardTab) {
        NotificationCenter.default.post(
            name: .navigateToDashboardTab,
            object: nil,
            userInfo: ["tab": tab.rawValue]
        )
        activateAndOpenDashboard()
    }

    /// Robustly open dashboard even from fullscreen apps
    private func activateAndOpenDashboard() {
        // Activate app first to ensure we switch spaces if needed
        NSApp.activate(ignoringOtherApps: true)
        // Open window after a brief delay so the space switch completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            openWindow(id: "dashboard")
            // Second activation to bring the new window to front
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NSApp.activate(ignoringOtherApps: true)
                // Also find and bring dashboard window to front explicitly
                for window in NSApp.windows where window.title == "Reflex Dashboard" {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
    }
}
