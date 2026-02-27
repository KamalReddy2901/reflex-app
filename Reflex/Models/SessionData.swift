import Foundation

struct SessionData: Identifiable, Codable {
    let id: UUID
    var startTime: Date
    var endTime: Date?
    var loadSamples: [LoadSample]
    var breaksTaken: Int
    var averageLoad: Double
    var peakLoad: Int
    var totalKeystrokes: Int
    var totalAppSwitches: Int

    var duration: TimeInterval {
        (endTime ?? .now).timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var isActive: Bool {
        endTime == nil
    }

    init(id: UUID = UUID(), startTime: Date = .now) {
        self.id = id
        self.startTime = startTime
        self.endTime = nil
        self.loadSamples = []
        self.breaksTaken = 0
        self.averageLoad = 0
        self.peakLoad = 0
        self.totalKeystrokes = 0
        self.totalAppSwitches = 0
    }
}

struct LoadSample: Codable {
    let timestamp: Date
    let score: Int
    let level: CognitiveLoadLevel
}
