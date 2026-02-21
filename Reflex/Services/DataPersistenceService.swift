import Foundation

@MainActor
class DataPersistenceService: ObservableObject {
    @Published var sessions: [SessionData] = []
    @Published var currentSession: SessionData?

    private let fileManager = FileManager.default

    init() {
        loadSessions()
    }

    // MARK: - Session Management

    func startNewSession() {
        let session = SessionData()
        currentSession = session
    }

    func endCurrentSession(loadHistory: [LoadSample], breaksTaken: Int, totalKeystrokes: Int, totalAppSwitches: Int) {
        guard var session = currentSession else { return }
        session.endTime = .now
        session.loadSamples = loadHistory
        session.breaksTaken = breaksTaken
        session.totalKeystrokes = totalKeystrokes
        session.totalAppSwitches = totalAppSwitches

        if !session.loadSamples.isEmpty {
            session.averageLoad = Double(session.loadSamples.map(\.score).reduce(0, +)) / Double(session.loadSamples.count)
            session.peakLoad = session.loadSamples.map(\.score).max() ?? 0
        }

        sessions.append(session)
        saveSessions()
        currentSession = nil
    }

    func updateCurrentSession(loadSample: LoadSample) {
        currentSession?.loadSamples.append(loadSample)
    }

    // MARK: - Persistence

    private func getSessionsDirectory() -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent(ReflexConstants.appSupportDirectory)
            .appendingPathComponent(ReflexConstants.sessionsDirectory)
    }

    private func saveSessions() {
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

    private func loadSessions() {
        let url = getSessionsDirectory().appendingPathComponent("sessions.json")
        guard let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode([SessionData].self, from: data) else {
            return
        }
        sessions = loaded
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
        return hourScores.min(by: { $0.value.average < $1.value.average })?.key
    }

    func exportToCSV() -> URL? {
        var csv = "Session ID,Start Time,End Time,Duration (min),Avg Load,Peak Load,Breaks,Keystrokes,App Switches\n"

        let formatter = ISO8601DateFormatter()

        for session in sessions {
            let start = formatter.string(from: session.startTime)
            let end = session.endTime.map { formatter.string(from: $0) } ?? "ongoing"
            let duration = String(format: "%.1f", session.duration / 60)
            csv += "\(session.id),\(start),\(end),\(duration),\(String(format: "%.1f", session.averageLoad)),\(session.peakLoad),\(session.breaksTaken),\(session.totalKeystrokes),\(session.totalAppSwitches)\n"
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
