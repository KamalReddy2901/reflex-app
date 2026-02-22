import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var loadEngine: CognitiveLoadEngine
    @EnvironmentObject var permissionService: AccessibilityPermissionService
    @EnvironmentObject var persistenceService: DataPersistenceService
    @EnvironmentObject var breakService: BreakReminderService
    @EnvironmentObject var keystrokeAnalyzer: KeystrokeAnalyzer
    @EnvironmentObject var mouseAnalyzer: MouseBehaviorAnalyzer
    @EnvironmentObject var appSwitchMonitor: AppSwitchMonitor

    @State private var selectedTab: NavigationState.DashboardTab = .overview

    var body: some View {
        ZStack {
            MeshGradientBackground(intensity: Double(loadEngine.currentScore) / 100.0)

            NavigationSplitView {
                sidebarContent
                    .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            } detail: {
                detailContent
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToDashboardTab)) { notification in
                if let rawValue = notification.userInfo?["tab"] as? String,
                   let tab = NavigationState.DashboardTab(rawValue: rawValue) {
                    selectedTab = tab
                }
            }
        }
        .frame(minWidth: ReflexConstants.dashboardMinWidth, minHeight: ReflexConstants.dashboardMinHeight)
        .sheet(isPresented: Binding(
            get: { !permissionService.isGranted },
            set: { newValue in
                // Allow dismissal — user may have granted via System Settings directly
                if !newValue {
                    permissionService.checkPermission()
                }
            }
        )) {
            PermissionRequestView()
                .environmentObject(permissionService)
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 28))
                    .foregroundColor(.reflexPurple)

                Text("Reflex Beta")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                MiniLoadRing(score: loadEngine.currentScore, size: 32)
            }
            .padding(.vertical, 20)

            Divider()
                .background(.white.opacity(0.1))

            List(NavigationState.DashboardTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.6))
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 4) {
                HStack {
                    Circle()
                        .fill(permissionService.isGranted ? .green : .red)
                        .frame(width: 6, height: 6)
                    Text(permissionService.isGranted ? "Monitoring Active" : "Permission Required")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }

                if loadEngine.isCalibrating {
                    Text("Calibrating...")
                        .font(.caption2)
                        .foregroundColor(.yellow.opacity(0.7))
                }
            }
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial.opacity(0.5))
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        ScrollView {
            switch selectedTab {
            case .overview:
                OverviewContent()
            case .history:
                SessionHistoryView()
            case .insights:
                InsightsView()
            case .settings:
                SettingsView()
            }
        }
        .scrollContentBackground(.hidden)
        .id(selectedTab) // force refresh when tab changes via notification
    }
}

// MARK: - Overview Content

struct OverviewContent: View {
    @EnvironmentObject var loadEngine: CognitiveLoadEngine
    @EnvironmentObject var keystrokeAnalyzer: KeystrokeAnalyzer
    @EnvironmentObject var mouseAnalyzer: MouseBehaviorAnalyzer
    @EnvironmentObject var appSwitchMonitor: AppSwitchMonitor
    @EnvironmentObject var breakService: BreakReminderService
    @EnvironmentObject var persistenceService: DataPersistenceService

    var body: some View {
        VStack(spacing: 20) {
            // Top row: Ring + Chart
            HStack(spacing: 20) {
                GlassMorphicCard {
                    VStack(spacing: 12) {
                        CognitiveLoadRing(score: loadEngine.currentScore, size: 160, lineWidth: 14)

                        Text(loadEngine.suggestion)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .frame(maxWidth: 200)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .frame(maxWidth: 280)

                // Real-time chart
                GlassMorphicCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cognitive Load — Past Hour")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.7))

                        if loadEngine.loadHistory.count > 1 {
                            Chart(loadEngine.loadHistory.indices, id: \.self) { index in
                                let sample = loadEngine.loadHistory[index]
                                LineMark(
                                    x: .value("Time", sample.timestamp),
                                    y: .value("Load", sample.score)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.reflexPurple, .reflexBlue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .interpolationMethod(.catmullRom)

                                AreaMark(
                                    x: .value("Time", sample.timestamp),
                                    y: .value("Load", sample.score)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.reflexPurple.opacity(0.3), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)
                            }
                            .chartYScale(domain: 0...100)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .minute, count: 10)) { _ in
                                    AxisValueLabel(format: .dateTime.hour().minute())
                                        .foregroundStyle(.white.opacity(0.5))
                                    AxisGridLine()
                                        .foregroundStyle(.white.opacity(0.1))
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { _ in
                                    AxisValueLabel()
                                        .foregroundStyle(.white.opacity(0.5))
                                    AxisGridLine()
                                        .foregroundStyle(.white.opacity(0.1))
                                }
                            }
                            .frame(height: 160)
                        } else {
                            Text("Collecting data...")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                                .frame(height: 160)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }

            // Session stats
            HStack(spacing: 12) {
                sessionStatCard(title: "Session", value: persistenceService.currentSession?.formattedDuration ?? "—", icon: "timer")
                sessionStatCard(title: "Breaks", value: "\(breakService.breaksTaken)", icon: "cup.and.saucer")
                sessionStatCard(title: "Keystrokes", value: "\(keystrokeAnalyzer.metrics.totalKeystrokes)", icon: "keyboard")
                sessionStatCard(title: "App Switches", value: String(format: "%.1f/min", appSwitchMonitor.metrics.switchesPerMinute), icon: "arrow.triangle.swap")
            }

            // Detailed metrics
            HStack(spacing: 12) {
                GlassMorphicCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Typing Analysis", systemImage: "keyboard")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))

                        metricRow("Overall Speed", String(format: "%.0f WPM", keystrokeAnalyzer.metrics.wordsPerMinute), hint: "Includes idle time")
                        metricRow("Burst Speed", String(format: "%.0f WPM", keystrokeAnalyzer.metrics.burstWordsPerMinute), hint: "During active typing")
                        metricRow("Rhythm Variance", String(format: "%.2f CV", keystrokeAnalyzer.metrics.coefficientOfVariation), hint: "Keypress consistency")
                        metricRow("Error Rate", String(format: "%.1f%%", keystrokeAnalyzer.metrics.backspaceRatio * 100), hint: "Backspace usage")
                        metricRow("Pause Rate", String(format: "%.1f/min", keystrokeAnalyzer.metrics.pauseFrequency), hint: "Hesitation frequency")
                    }
                }

                GlassMorphicCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Mouse & Focus", systemImage: "computermouse")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))

                        metricRow("Mouse Jitter", mouseAnalyzer.metrics.jitterLevel.rawValue, hint: "Movement steadiness")
                        metricRow("Scroll Rate", String(format: "%.1f/min", mouseAnalyzer.metrics.scrollFrequency), hint: "Scroll events")
                        metricRow("Dir. Changes", "\(mouseAnalyzer.metrics.scrollDirectionChanges)", hint: "Scroll direction flips")
                        metricRow("Current App", appSwitchMonitor.metrics.currentApp)
                    }
                }
            }
        }
        .padding(20)
    }

    private func sessionStatCard(title: String, value: String, icon: String) -> some View {
        GlassMorphicCard(tintColor: .white.opacity(0.03)) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.reflexBlue)

                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text(title)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func metricRow(_ label: String, _ value: String, hint: String? = nil) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
            if let hint = hint {
                HStack {
                    Spacer()
                    Text(hint)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
    }
}
