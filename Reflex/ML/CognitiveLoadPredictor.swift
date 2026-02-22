import Foundation
import CoreML

// MARK: - Predictor Protocol

protocol CognitiveLoadPredictor {
    func predict(from snapshot: BehaviorSnapshot) -> CognitiveLoadLevel
    func predictScore(from snapshot: BehaviorSnapshot) -> Int
}

// MARK: - Heuristic Predictor (Default)

class HeuristicPredictor: CognitiveLoadPredictor {
    func predict(from snapshot: BehaviorSnapshot) -> CognitiveLoadLevel {
        CognitiveLoadLevel.from(score: predictScore(from: snapshot))
    }

    func predictScore(from snapshot: BehaviorSnapshot) -> Int {
        // Typing variance (CV > 0.5 is high)
        let typingScore = min(1.0, snapshot.typingIntervalCV / 0.8)

        // Error rate (> 10% is high)
        let errorScore = min(1.0, snapshot.backspaceRatio / 0.15)

        // App switching (> 6/min is high)
        let switchScore = min(1.0, snapshot.appSwitchRate / 8.0)

        // Mouse jitter (variance > 30000 is high)
        let jitterScore = min(1.0, snapshot.mouseJitter / 50000.0)

        // Pause frequency (> 4/min is high)
        let pauseScore = min(1.0, snapshot.pauseFrequency / 5.0)

        // Scroll chaos (> 10 direction changes is high)
        let scrollScore = min(1.0, snapshot.scrollDirectionChanges / 15.0)

        let score = typingScore * 0.25
            + errorScore * 0.20
            + switchScore * 0.20
            + jitterScore * 0.15
            + pauseScore * 0.10
            + scrollScore * 0.10

        let raw = score * 100
        guard raw.isFinite else { return 0 }
        return Int(min(100, max(0, raw)))
    }
}

// MARK: - Core ML Predictor (Future)

class CoreMLPredictor: CognitiveLoadPredictor {
    private var model: MLModel?

    init() {
        // TODO: Load trained .mlmodel when available
        // model = try? CognitiveLoadClassifier(configuration: .init()).model
    }

    func predict(from snapshot: BehaviorSnapshot) -> CognitiveLoadLevel {
        CognitiveLoadLevel.from(score: predictScore(from: snapshot))
    }

    func predictScore(from snapshot: BehaviorSnapshot) -> Int {
        guard let model = model,
              let features = FeatureExtractor.createMLFeatureProvider(from: snapshot),
              let prediction = try? model.prediction(from: features) else {
            return HeuristicPredictor().predictScore(from: snapshot)
        }

        if let scoreFeature = prediction.featureValue(for: "cognitive_load_score") {
            return Int(scoreFeature.doubleValue)
        }

        return HeuristicPredictor().predictScore(from: snapshot)
    }
}

// MARK: - Training Data Collector

class TrainingDataCollector {
    private var samples: [(BehaviorSnapshot, Int)] = []

    func recordSample(snapshot: BehaviorSnapshot, userLabel: Int) {
        samples.append((snapshot, userLabel))

        if samples.count % 100 == 0 {
            saveToCSV()
        }
    }

    func saveToCSV() {
        let headers = "typing_interval_mean,typing_interval_cv,backspace_ratio,pause_frequency,mouse_jitter,mouse_idle_ratio,scroll_direction_changes,app_switch_rate,unique_apps,rapid_switch_bursts,label\n"

        var csv = headers
        for (snapshot, label) in samples {
            let features = FeatureExtractor.extractFeatures(from: snapshot)
            let values = [
                features["typing_interval_mean"]!,
                features["typing_interval_cv"]!,
                features["backspace_ratio"]!,
                features["pause_frequency"]!,
                features["mouse_jitter"]!,
                features["mouse_idle_ratio"]!,
                features["scroll_direction_changes"]!,
                features["app_switch_rate"]!,
                features["unique_apps"]!,
                features["rapid_switch_bursts"]!,
            ]
            csv += values.map { String(format: "%.6f", $0) }.joined(separator: ",")
            csv += ",\(label)\n"
        }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent(ReflexConstants.appSupportDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("training_data.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }
}
