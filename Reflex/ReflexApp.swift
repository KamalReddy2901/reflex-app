import SwiftUI
import Combine

@main
struct ReflexApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Services
    @StateObject private var permissionService = AccessibilityPermissionService()
    @StateObject private var eventMonitor = EventMonitorService()
    @StateObject private var keystrokeAnalyzer = KeystrokeAnalyzer()
    @StateObject private var mouseAnalyzer = MouseBehaviorAnalyzer()
    @StateObject private var appSwitchMonitor = AppSwitchMonitor()
    @StateObject private var breakService = BreakReminderService()
    @StateObject private var persistenceService = DataPersistenceService()

    @AppStorage("breakDurationMinutes") private var breakDurationMinutes = 5
    @AppStorage("breathingExerciseEnabled") private var breathingExerciseEnabled = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("sensitivityLevel") private var sensitivityLevel = 0.5

    @State private var loadEngine: CognitiveLoadEngine?
    @State private var isInitialized = false
    @State private var onboardingComplete = false
    @State private var cancellables = Set<AnyCancellable>()

    var body: some Scene {
        // Menu Bar
        MenuBarExtra {
            if let engine = loadEngine {
                MenuBarView()
                    .environmentObject(engine)
                    .environmentObject(permissionService)
                    .environmentObject(breakService)
                    .environmentObject(keystrokeAnalyzer)
                    .environmentObject(mouseAnalyzer)
                    .environmentObject(appSwitchMonitor)
            } else {
                ProgressView("Initializing...")
                    .padding()
            }
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        // Main Dashboard Window
        Window("Reflex Dashboard", id: "dashboard") {
            if let engine = loadEngine {
                DashboardView()
                    .environmentObject(engine)
                    .environmentObject(permissionService)
                    .environmentObject(persistenceService)
                    .environmentObject(breakService)
                    .environmentObject(keystrokeAnalyzer)
                    .environmentObject(mouseAnalyzer)
                    .environmentObject(appSwitchMonitor)
            } else {
                ProgressView("Initializing...")
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: ReflexConstants.dashboardMinWidth, height: ReflexConstants.dashboardMinHeight)
        .commandsRemoved()

        // Onboarding Window
        Window("Welcome to Reflex", id: "onboarding") {
            OnboardingView(isComplete: $onboardingComplete)
                .environmentObject(permissionService)
                .onChange(of: onboardingComplete) { _, complete in
                    if complete {
                        hasCompletedOnboarding = true
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commandsRemoved()
    }

    // MARK: - Menu Bar Label

    private var menuBarLabel: some View {
        OnboardingTriggerView(
            hasCompletedOnboarding: $hasCompletedOnboarding,
            loadEngine: loadEngine,
            isInitialized: $isInitialized
        ) {
            initializeServices()
        }
    }

    // MARK: - Service Initialization

    private func initializeServices() {
        guard !isInitialized else { return }
        isInitialized = true

        let engine = CognitiveLoadEngine(
            keystrokeAnalyzer: keystrokeAnalyzer,
            mouseAnalyzer: mouseAnalyzer,
            appSwitchMonitor: appSwitchMonitor
        )
        self.loadEngine = engine

        // Sync sensitivity setting
        engine.sensitivityMultiplier = sensitivityLevel

        // Wire event monitor to analyzers
        eventMonitor.onKeyDown = { [weak keystrokeAnalyzer] time in
            Task { @MainActor in
                keystrokeAnalyzer?.recordKeystroke(at: time)
            }
        }

        eventMonitor.onBackspace = { [weak keystrokeAnalyzer] time in
            Task { @MainActor in
                keystrokeAnalyzer?.recordBackspace(at: time)
            }
        }

        eventMonitor.onMouseMoved = { [weak mouseAnalyzer] position, time in
            Task { @MainActor in
                mouseAnalyzer?.recordMouseMove(position: position, at: time)
            }
        }

        eventMonitor.onScrollWheel = { [weak mouseAnalyzer] dx, dy, time in
            Task { @MainActor in
                mouseAnalyzer?.recordScroll(deltaX: dx, deltaY: dy, at: time)
            }
        }

        // Start services when permission is granted
        setupPermissionObserver(engine: engine)

        // Start a new session
        persistenceService.startNewSession()

        // Set up break notification observers
        setupBreakNotificationObservers()

        // Set up break trigger monitoring
        setupBreakTriggerMonitor(engine: engine)
    }

    private func setupPermissionObserver(engine: CognitiveLoadEngine) {
        Task { @MainActor in
            if permissionService.isGranted {
                startMonitoring(engine: engine)
            }

            // React when permission changes from false → true
            // The AccessibilityPermissionService already polls every 2s
            permissionService.$isGranted
                .removeDuplicates()
                .filter { $0 }
                .sink { [weak engine] _ in
                    guard let engine else { return }
                    Task { @MainActor in
                        self.startMonitoring(engine: engine)
                    }
                }
                .store(in: &cancellables)
        }
    }

    private func startMonitoring(engine: CognitiveLoadEngine) {
        eventMonitor.startMonitoring()
        appSwitchMonitor.startMonitoring()
        engine.startEngine()
    }

    private func setupBreakNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .takeBreak, object: nil, queue: .main
        ) { notification in
            let durationMinutes = notification.userInfo?["durationMinutes"] as? Int
            Task { @MainActor in
                breakService.startBreak(durationMinutes: durationMinutes)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .snoozeBreak, object: nil, queue: .main
        ) { notification in
            if let minutes = notification.userInfo?["minutes"] as? Int {
                Task { @MainActor in
                    breakService.snooze(minutes: minutes)
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .skipBreak, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                breakService.skipBreak()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .dismissBreak, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                breakService.dismiss()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .endBreakEarly, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                breakService.endBreakEarly()
            }
        }

        // Sync user preferences to service
        breakService.selectedBreakDurationMinutes = breakDurationMinutes
        breakService.breathingExerciseEnabled = breathingExerciseEnabled
        breakService.startSession()

        // Save session data on app termination
        NotificationCenter.default.addObserver(
            forName: .appWillTerminate, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                if let engine = self.loadEngine {
                    self.persistenceService.endCurrentSession(
                        loadHistory: engine.loadHistory,
                        breaksTaken: self.breakService.breaksTaken,
                        totalKeystrokes: self.keystrokeAnalyzer.metrics.totalKeystrokes,
                        totalAppSwitches: self.appSwitchMonitor.totalSwitches
                    )
                }
            }
        }
    }

    private func setupBreakTriggerMonitor(engine: CognitiveLoadEngine) {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                if engine.minutesAtHighLoad >= 10 && !engine.hasTriggeredBreak {
                    self.breakService.sendBreakReminder(
                        loadScore: engine.currentScore,
                        minutesAtHighLoad: engine.minutesAtHighLoad
                    )
                    engine.hasTriggeredBreak = true
                }

                if engine.minutesAtHighLoad < 5 {
                    engine.hasTriggeredBreak = false
                }
            }
        }
    }

}
