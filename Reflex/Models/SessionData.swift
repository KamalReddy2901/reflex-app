import Foundation

struct SessionData: Identifiable, Codable {
    let id: UUID
    var startTime: Date
    var endTime: Date?
    var loadSamples: [LoadSample]
    var breaksTaken: Int
    /// Breaks triggered by high cognitive load (subset of breaksTaken).
    var cognitiveBreaksTaken: Int
    /// Eye-rest (20-20-20) breaks completed (subset / independent of breaksTaken).
    var eyeRestBreaksTaken: Int
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
        self.cognitiveBreaksTaken = 0
        self.eyeRestBreaksTaken = 0
        self.averageLoad = 0
        self.peakLoad = 0
        self.totalKeystrokes = 0
        self.totalAppSwitches = 0
    }

    // MARK: - Backward-compatible Codable (handles old JSON without new fields)
    enum CodingKeys: String, CodingKey {
        case id, startTime, endTime, loadSamples, breaksTaken
        case cognitiveBreaksTaken, eyeRestBreaksTaken
        case averageLoad, peakLoad, totalKeystrokes, totalAppSwitches
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        startTime = try c.decode(Date.self, forKey: .startTime)
        endTime = try c.decodeIfPresent(Date.self, forKey: .endTime)
        loadSamples = try c.decodeIfPresent([LoadSample].self, forKey: .loadSamples) ?? []
        breaksTaken = try c.decodeIfPresent(Int.self, forKey: .breaksTaken) ?? 0
        cognitiveBreaksTaken = try c.decodeIfPresent(Int.self, forKey: .cognitiveBreaksTaken) ?? 0
        eyeRestBreaksTaken = try c.decodeIfPresent(Int.self, forKey: .eyeRestBreaksTaken) ?? 0
        averageLoad = try c.decodeIfPresent(Double.self, forKey: .averageLoad) ?? 0
        peakLoad = try c.decodeIfPresent(Int.self, forKey: .peakLoad) ?? 0
        totalKeystrokes = try c.decodeIfPresent(Int.self, forKey: .totalKeystrokes) ?? 0
        totalAppSwitches = try c.decodeIfPresent(Int.self, forKey: .totalAppSwitches) ?? 0
    }
}

struct LoadSample: Codable {
    let timestamp: Date
    let score: Int
    let level: CognitiveLoadLevel
}
