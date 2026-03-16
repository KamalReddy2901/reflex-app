import Foundation

@MainActor
class DataPersistenceService: ObservableObject {
    @Published var sessions: [SessionData] = []
    @Published var currentSession: SessionData?

    private let fileManager = FileManager.default
    private var autoSaveTimer: Timer?

    init() {
        startAutoSaveTimer()
        // Defer disk I/O off the main thread to avoid blocking the UI on startup.
        // Sessions are typically small but can grow over months of daily use.
        Task { [weak self] in
            guard let self else { return }
            await self.loadSessionsAsync()
        }
    }

    deinit {
        autoSaveTimer?.invalidate()
    }

    private func startAutoSaveTimer() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.saveCurrentSession()
            }
        }
    }

    // MARK: - Session Management

    func startNewSession() {
        let session = SessionData()
        currentSession = session
    }

    func endCurrentSession(
        loadHistory: [LoadSample],
        breaksTaken: Int,
        cognitiveBreaksTaken: Int = 0,
        eyeRestBreaksTaken: Int = 0,
        totalKeystrokes: Int,
        totalAppSwitches: Int,
        overrideEndTime: Date? = nil
    ) {
        guard var session = currentSession else { return }
        session.endTime = overrideEndTime ?? .now
        session.loadSamples = loadHistory
        session.breaksTaken = breaksTaken
        session.cognitiveBreaksTaken = cognitiveBreaksTaken
        session.eyeRestBreaksTaken = eyeRestBreaksTaken
        session.totalKeystrokes = totalKeystrokes
        session.totalAppSwitches = totalAppSwitches

        if !session.loadSamples.isEmpty {
            session.averageLoad = Double(session.loadSamples.map(\.score).reduce(0, +)) / Double(session.loadSamples.count)
            session.peakLoad = session.loadSamples.map(\.score).max() ?? 0
        }

        sessions.append(session)
        saveSessions()
        currentSession = nil
        
        let currentUrl = getSessionsDirectory().appendingPathComponent("current_session.json")
        try? fileManager.removeItem(at: currentUrl)
    }

    func updateCurrentSession(loadSample: LoadSample) {
        currentSession?.loadSamples.append(loadSample)
    }

    func updateCurrentSessionSnapshot(
        loadHistory: [LoadSample],
        breaksTaken: Int,
        cognitiveBreaksTaken: Int = 0,
        eyeRestBreaksTaken: Int = 0,
        totalKeystrokes: Int,
        totalAppSwitches: Int
    ) {
        guard var session = currentSession else { return }
        session.loadSamples = loadHistory
        session.breaksTaken = breaksTaken
        session.cognitiveBreaksTaken = cognitiveBreaksTaken
        session.eyeRestBreaksTaken = eyeRestBreaksTaken
        session.totalKeystrokes = totalKeystrokes
        session.totalAppSwitches = totalAppSwitches

        if !session.loadSamples.isEmpty {
            session.averageLoad = Double(session.loadSamples.map(\.score).reduce(0, +)) / Double(session.loadSamples.count)
            session.peakLoad = session.loadSamples.map(\.score).max() ?? 0
        } else {
            session.averageLoad = 0
            session.peakLoad = 0
        }

        currentSession = session
    }

    // MARK: - Persistence

    private func getSessionsDirectory() -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent(ReflexConstants.appSupportDirectory)
            .appendingPathComponent(ReflexConstants.sessionsDirectory)
    }

    private func saveSessions() {
        // Cap session history to last 500 sessions to prevent the JSON file
        // from growing unboundedly over months of daily use.
        if sessions.count > 500 {
            sessions.removeFirst(sessions.count - 500)
        }
        let directory = getSessionsDirectory()
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("sessions.json")
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: url)
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }

    private func saveCurrentSession() {
        guard let currentSession = currentSession else { return }
        let directory = getSessionsDirectory()
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("current_session.json")
            let data = try JSONEncoder().encode(currentSession)
            try data.write(to: url)
        } catch {
            print("Failed to save current session: \(error)")
        }
    }

    private func loadSessionsAsync() async {
        let directory = getSessionsDirectory()
        // Perform disk I/O off the main thread
        let result: ([SessionData], SessionData?) = await Task.detached(priority: .userInitiated) {
            let url = directory.appendingPathComponent("sessions.json")
            var loadedSessions: [SessionData] = []
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([SessionData].self, from: data) {
                loadedSessions = decoded
            }

            // Recover a crash-interrupted session if one exists
            let currentUrl = directory.appendingPathComponent("current_session.json")
            var recovered: SessionData? = nil
            if let data = try? Data(contentsOf: currentUrl),
               var loadedCurrent = try? JSONDecoder().decode(SessionData.self, from: data) {
                let maxReasonableDuration: TimeInterval = 8 * 3600
                let lastSampleTime = loadedCurrent.loadSamples.last?.timestamp
                let naturalEnd = lastSampleTime ?? loadedCurrent.startTime
                let elapsed = Date.now.timeIntervalSince(loadedCurrent.startTime)
                if elapsed > maxReasonableDuration {
                    loadedCurrent.endTime = naturalEnd
                } else {
                    loadedCurrent.endTime = .now
                }
                if !loadedCurrent.loadSamples.isEmpty {
                    loadedCurrent.averageLoad = Double(loadedCurrent.loadSamples.map(\.score).reduce(0, +)) / Double(loadedCurrent.loadSamples.count)
                    loadedCurrent.peakLoad = loadedCurrent.loadSamples.map(\.score).max() ?? 0
                }
                recovered = loadedCurrent
                try? FileManager.default.removeItem(at: currentUrl)
            }
            return (loadedSessions, recovered)
        }.value

        // Apply on MainActor (self is @MainActor so this resumes here)
        var allSessions = result.0
        if let recoveredSession = result.1 {
            allSessions.append(recoveredSession)
        }
        self.sessions = allSessions
        if result.1 != nil {
            saveSessions()
        }
    }

    // MARK: - Analytics

    func averageLoadForPastDays(_ days: Int) -> Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let recentSessions = sessions.filter { $0.startTime >= cutoff }
        guard !recentSessions.isEmpty else { return 0 }
        return recentSessions.map(\.averageLoad).reduce(0, +) / Double(recentSessions.count)
    }

    func totalSessionTime(forPastDays days: Int) -> TimeInterval {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        return sessions.filter { $0.startTime >= cutoff }.map(\.duration).reduce(0, +)
    }

    func bestFocusHour() -> Int? {
        var hourScores: [Int: [Double]] = [:]
        for session in sessions {
            for sample in session.loadSamples {
                let hour = Calendar.current.component(.hour, from: sample.timestamp)
                hourScores[hour, default: []].append(Double(sample.score))
            }
        }
        // Find the hour with the LOWEST average load — that's when the user is
        // most likely in a Flow state (low load = deep, effortless focus).
        return hourScores.min(by: { $0.value.average < $1.value.average })?.key
    }

    func exportToCSV() -> URL? {
        var csv = "Session ID,Start Time,End Time,Duration (min),Avg Load,Peak Load,Total Breaks,Load Breaks,Eye Rest Breaks,Keystrokes,App Switches\n"

        let formatter = ISO8601DateFormatter()

        for session in sessions {
            let start = formatter.string(from: session.startTime)
            let end = session.endTime.map { formatter.string(from: $0) } ?? "ongoing"
            let duration = String(format: "%.1f", session.duration / 60)
            csv += "\(session.id),\(start),\(end),\(duration),\(String(format: "%.1f", session.averageLoad)),\(session.peakLoad),\(session.breaksTaken),\(session.cognitiveBreaksTaken),\(session.eyeRestBreaksTaken),\(session.totalKeystrokes),\(session.totalAppSwitches)\n"
        }

        let directory = getSessionsDirectory()
        let url = directory.appendingPathComponent("reflex_export.csv")

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("Failed to export CSV: \(error)")
            return nil
        }
    }

    func clearAllData() {
        sessions.removeAll()
        currentSession = nil
        let directory = getSessionsDirectory()
        try? fileManager.removeItem(at: directory)
    }
}
