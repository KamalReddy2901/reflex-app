import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var permissionService: AccessibilityPermissionService
    @EnvironmentObject var persistenceService: DataPersistenceService
    @EnvironmentObject var breakService: BreakReminderService
    @EnvironmentObject var loadEngine: CognitiveLoadEngine

    @AppStorage("monitoringEnabled") private var monitoringEnabled = true
    @AppStorage("breakRemindersEnabled") private var breakRemindersEnabled = true
    @AppStorage("breakIntervalMinutes") private var breakIntervalMinutes = 15
    @AppStorage("breakDurationMinutes") private var breakDurationMinutes = 5
    @AppStorage("breathingExerciseEnabled") private var breathingExerciseEnabled = true
    @AppStorage("sensitivityLevel") private var sensitivityLevel = 0.5
    @AppStorage("showInDock") private var showInDock = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("eyeRestEnabled") private var eyeRestEnabled = true
    @AppStorage("eyeRestIntervalMinutes") private var eyeRestIntervalMinutes = ReflexConstants.eyeRestDefaultIntervalMinutes
    @AppStorage("focusBreakIntervalMinutes") private var focusBreakIntervalMinutes = ReflexConstants.defaultFocusBreakIntervalMinutes
    @AppStorage("hydrationReminderEnabled") private var hydrationReminderEnabled = false
    @AppStorage("hydrationIntervalMinutes") private var hydrationIntervalMinutes = ReflexConstants.hydrationDefaultIntervalMinutes
    @AppStorage("skipCooldownMinutes") private var skipCooldownMinutes = ReflexConstants.defaultSkipCooldownMinutes

    @State private var showClearConfirmation = false
    @State private var showResetBaseline = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            // Permissions
            GlassMorphicCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Permissions", systemImage: "lock.shield")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))

                    HStack {
                        Image(systemName: permissionService.isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(permissionService.isGranted ? .green : .red)

                        Text("Accessibility Access")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))

                        Spacer()

                        if !permissionService.isGranted {
                            Button("Grant Access") {
                                permissionService.requestPermission()
                            }
                            .font(.caption)
                            .buttonStyle(.borderedProminent)
                            .tint(.reflexPurple)
                        } else {
                            Text("Granted")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }

                    Text("Required for monitoring typing and mouse patterns across all apps.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Monitoring
            GlassMorphicCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Monitoring", systemImage: "waveform.path.ecg")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))

                    Toggle("Enable Monitoring", isOn: $monitoringEnabled)
                        .tint(.reflexPurple)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .onChange(of: monitoringEnabled) { _, newValue in
                            if newValue {
                                loadEngine.startEngine()
                            } else {
                                loadEngine.stopEngine()
                            }
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Sensitivity")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text(sensitivityLabel)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Slider(value: $sensitivityLevel, in: 0...1)
                            .tint(.reflexPurple)
                            .onChange(of: sensitivityLevel) { _, newValue in
                                loadEngine.sensitivityMultiplier = newValue
                            }
                    }

                    Text("Higher sensitivity means the app will detect cognitive load changes more aggressively.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Break Reminders
            GlassMorphicCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Break Reminders", systemImage: "bell")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))

                    Toggle("Enable Break Reminders", isOn: $breakRemindersEnabled)
                        .tint(.reflexPurple)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .onChange(of: breakRemindersEnabled) { _, newValue in
                            breakService.setReminderEnabled(newValue)
                        }

                    HStack {
                        Text("Remind after")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))

                        Picker("", selection: $breakIntervalMinutes) {
                            Text("10 min").tag(10)
                            Text("15 min").tag(15)
                            Text("20 min").tag(20)
                            Text("30 min").tag(30)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)
                        .onChange(of: breakIntervalMinutes) { _, newValue in
                            breakService.setReminderInterval(TimeInterval(newValue * 60))
                        }

                        Text("of high load")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    HStack {
                        Text("Break duration")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))

                        Picker("", selection: $breakDurationMinutes) {
                            Text("2 min").tag(2)
                            Text("5 min").tag(5)
                            Text("10 min").tag(10)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 200)
                        .onChange(of: breakDurationMinutes) { _, newValue in
                            breakService.selectedBreakDurationMinutes = newValue
                        }
                    }

                    Toggle("Breathing exercise during break", isOn: $breathingExerciseEnabled)
                        .tint(.green)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .onChange(of: breathingExerciseEnabled) { _, newValue in
                            breakService.breathingExerciseEnabled = newValue
                        }

                    Text("When off, breaks show a simple countdown timer without guided breathing.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))

                    Divider()
                        .background(Color.white.opacity(0.1))

                    // Skip cooldown
                    HStack {
                        Text("After skipping, wait")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))

                        Picker("", selection: $skipCooldownMinutes) {
                            Text("20 min").tag(20)
                            Text("30 min").tag(30)
                            Text("45 min").tag(45)
                            Text("60 min").tag(60)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 280)
                        .onChange(of: skipCooldownMinutes) { _, newValue in
                            loadEngine.skipCooldownMinutes = newValue
                        }

                        Text("before re-alerting")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Text("After skipping a cognitive load break, Reflex will wait this long before reminding you again (prevents repeated interruptions).")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))

                    Divider()
                        .background(Color.white.opacity(0.1))

                    // Time-based break interval
                    HStack {
                        Text("Focus break after")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))

                        Picker("", selection: $focusBreakIntervalMinutes) {
                            Text("20 min").tag(20)
                            Text("25 min").tag(25)
                            Text("30 min").tag(30)
                            Text("45 min").tag(45)
                            Text("60 min").tag(60)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 350)
                        .onChange(of: focusBreakIntervalMinutes) { _, newValue in
                            breakService.focusBreakIntervalMinutes = newValue
                        }
                    }

                    Text("Triggers a break reminder after this many minutes of continuous activity, regardless of cognitive load score.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Eye Rest (20-20-20 Rule)
            GlassMorphicCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Eye Rest", systemImage: "eye")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))

                    Toggle("Enable Eye Rest Reminders", isOn: $eyeRestEnabled)
                        .tint(.blue)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .onChange(of: eyeRestEnabled) { _, newValue in
                            breakService.eyeRestEnabled = newValue
                        }

                    HStack {
                        Text("Remind every")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))

                        Picker("", selection: $eyeRestIntervalMinutes) {
                            Text("20 min").tag(20)
                            Text("30 min").tag(30)
                            Text("40 min").tag(40)
                            Text("60 min").tag(60)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 280)
                        .onChange(of: eyeRestIntervalMinutes) { _, newValue in
                            breakService.eyeRestIntervalMinutes = newValue
                        }
                    }

                    Text("Based on the 20-20-20 rule: every 20 minutes, look at something 20 feet away for 20 seconds. Shows a quick 20-second fullscreen overlay.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Hydration
            GlassMorphicCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Wellness Reminders", systemImage: "drop")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))

                    Toggle("Hydration Reminders", isOn: $hydrationReminderEnabled)
                        .tint(.cyan)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .onChange(of: hydrationReminderEnabled) { _, newValue in
                            breakService.hydrationReminderEnabled = newValue
                        }

                    if hydrationReminderEnabled {
                        HStack {
                            Text("Remind every")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))

                            Picker("", selection: $hydrationIntervalMinutes) {
                                Text("30 min").tag(30)
                                Text("45 min").tag(45)
                                Text("60 min").tag(60)
                                Text("90 min").tag(90)
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 280)
                            .onChange(of: hydrationIntervalMinutes) { _, newValue in
                                breakService.hydrationIntervalMinutes = newValue
                            }
                        }
                    }

                    Text("Sends a gentle system notification to drink water. Small habit, big impact.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // General
            GlassMorphicCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("General", systemImage: "gearshape")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))

                    Toggle("Show in Dock", isOn: $showInDock)
                        .tint(.reflexPurple)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .onChange(of: showInDock) { _, newValue in
                            NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                        }

                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .tint(.reflexPurple)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .onChange(of: launchAtLogin) { _, newValue in
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                print("Failed to update login item: \(error)")
                                // Revert toggle on failure
                                launchAtLogin = !newValue
                            }
                        }
                }
            }

            // Data & Privacy
            GlassMorphicCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Data & Privacy", systemImage: "hand.raised")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))

                    Text("All data is stored locally on your Mac. Reflex Beta never transmits any data to external servers. No keystrokes are recorded — only timing patterns.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))

                    HStack(spacing: 12) {
                        Button("Export Data") {
                            if let url = persistenceService.exportToCSV() {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .font(.caption)
                        .glassButton()
                        .buttonStyle(.plain)
                        .foregroundColor(.white.opacity(0.7))

                        Button("Reset Baseline") {
                            showResetBaseline = true
                        }
                        .font(.caption)
                        .glassButton()
                        .buttonStyle(.plain)
                        .foregroundColor(.orange)

                        Button("Clear All Data") {
                            showClearConfirmation = true
                        }
                        .font(.caption)
                        .glassButton()
                        .buttonStyle(.plain)
                        .foregroundColor(.red)
                    }
                }
            }

            // Quit App
            GlassMorphicCard {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        HStack {
                            Image(systemName: "power")
                            Text("Quit Reflex Beta")
                            Spacer()
                        }
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Version
            HStack {
                Spacer()
                Text("Reflex Beta v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") — Built with ❤️ for focus")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
            }
        }
        .padding(20)
        .alert("Clear All Data?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                persistenceService.clearAllData()
            }
        } message: {
            Text("This will permanently delete all session history and preferences. This action cannot be undone.")
        }
        .alert("Reset Baseline?", isPresented: $showResetBaseline) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                loadEngine.reset()
            }
        } message: {
            Text("This will restart the calibration process. Reflex Beta will recalibrate to your current patterns over the next 30 minutes.")
        }
    }

    private var sensitivityLabel: String {
        switch sensitivityLevel {
        case 0..<0.3: return "Low"
        case 0.3..<0.7: return "Medium"
        default: return "High"
        }
    }
}
