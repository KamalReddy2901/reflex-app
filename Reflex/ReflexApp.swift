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
    @AppStorage("eyeRestEnabled") private var eyeRestEnabled = true
    @AppStorage("eyeRestIntervalMinutes") private var eyeRestIntervalMinutes = ReflexConstants.eyeRestDefaultIntervalMinutes
    @AppStorage("focusBreakIntervalMinutes") private var focusBreakIntervalMinutes = ReflexConstants.defaultFocusBreakIntervalMinutes
    @AppStorage("hydrationReminderEnabled") private var hydrationReminderEnabled = false
    @AppStorage("hydrationIntervalMinutes") private var hydrationIntervalMinutes = ReflexConstants.hydrationDefaultIntervalMinutes

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
                    .preferredColorScheme(.dark)
            } else {
                ProgressView("Initializing...")
                    .padding()
                    .preferredColorScheme(.dark)
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
                    .preferredColorScheme(.dark)
            } else {
                ProgressView("Initializing...")
                    .preferredColorScheme(.dark)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: ReflexConstants.dashboardMinWidth, height: ReflexConstants.dashboardMinHeight)
        .commandsRemoved()

        // Onboarding Window
        Window("Welcome to Reflex", id: "onboarding") {
            OnboardingView(isComplete: $onboardingComplete)
                .environmentObject(permissionService)
                .preferredColorScheme(.dark)
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
        eventMonitor.onKeyDown = { [weak keystrokeAnalyzer, weak engine] time in
            Task { @MainActor in
                keystrokeAnalyzer?.recordKeystroke(at: time)
                engine?.recordActivity()
            }
        }

        eventMonitor.onBackspace = { [weak keystrokeAnalyzer, weak engine] time in
            Task { @MainActor in
                keystrokeAnalyzer?.recordBackspace(at: time)
                engine?.recordActivity()
            }
        }

        eventMonitor.onMouseMoved = { [weak mouseAnalyzer, weak engine] position, time in
            Task { @MainActor in
                mouseAnalyzer?.recordMouseMove(position: position, at: time)
                engine?.recordActivity()
            }
        }

        eventMonitor.onScrollWheel = { [weak mouseAnalyzer, weak engine] dx, dy, time in
            Task { @MainActor in
                mouseAnalyzer?.recordScroll(deltaX: dx, deltaY: dy, at: time)
                engine?.recordActivity()
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
                self.loadEngine?.recordBreakTaken()
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
                self.loadEngine?.recordBreakTaken()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .breakEnded, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                self.loadEngine?.recordBreakTaken()
            }
        }

        // Eye rest observers
        NotificationCenter.default.addObserver(
            forName: .startEyeRest, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                breakService.startEyeRest()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .skipEyeRest, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                breakService.skipEyeRest()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .dismissEyeRest, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                breakService.dismissEyeRest()
            }
        }

        // Sync user preferences to service
        breakService.selectedBreakDurationMinutes = breakDurationMinutes
        breakService.breathingExerciseEnabled = breathingExerciseEnabled
        breakService.eyeRestEnabled = eyeRestEnabled
        breakService.eyeRestIntervalMinutes = eyeRestIntervalMinutes
        breakService.focusBreakIntervalMinutes = focusBreakIntervalMinutes
        breakService.hydrationReminderEnabled = hydrationReminderEnabled
        breakService.hydrationIntervalMinutes = hydrationIntervalMinutes
        breakService.startSession()

        // Save session data on app termination
        NotificationCenter.default.addObserver(
            forName: .appWillTerminate, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
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
        // Track if natural break was already credited for current idle period
        var naturalBreakCredited = false

        Timer.scheduledTimer(withTimeInterval: ReflexConstants.activityCheckInterval, repeats: true) { _ in
            Task { @MainActor in
                let activeMinutes = engine.continuousActiveMinutes
                let idleDuration = Date.now.timeIntervalSince(engine.lastInputTime)
                let isIdle = idleDuration >= ReflexConstants.naturalBreakThreshold

                // 1. Natural break detection: user has been idle for 2+ minutes
                if isIdle && !naturalBreakCredited {
                    naturalBreakCredited = true
                    self.breakService.recordNaturalBreak()
                    engine.recordBreakTaken()
                }

                // Reset natural break credit when user becomes active again
                if !isIdle {
                    naturalBreakCredited = false
                }

                // Only check triggers when user is active
                guard !isIdle else { return }

                // 2. Cognitive load-based break (existing, improved)
                // Trigger on 5+ accumulated minutes of high load (not just continuous)
                if engine.accumulatedHighLoadMinutes >= 5 && !engine.hasTriggeredBreak {
                    self.breakService.notificationPopup.mode = .breakReminder
                    self.breakService.sendBreakReminder(

                        loadScore: engine.currentScore,
                        minutesAtHighLoad: engine.minutesAtHighLoad
                    )
                    engine.hasTriggeredBreak = true
                }

                // Reset load-based trigger when accumulated high load drops
                if engine.accumulatedHighLoadMinutes < 2 {
                    engine.hasTriggeredBreak = false
                }

                // 3. Time-based break reminder (independent of cognitive load)
                if self.breakService.checkTimedBreak(
                    continuousActiveMinutes: activeMinutes,
                    hasTriggeredTimedBreak: engine.hasTriggeredTimedBreak
                ) {
                    engine.hasTriggeredTimedBreak = true
                }

                // 4. Eye rest check
                self.breakService.checkEyeRest()

                // 5. Hydration reminder check
                self.breakService.checkHydrationReminder()
            }
        }
    }

}
