import Foundation
import CoreML

class FeatureExtractor {

    static func extractFeatures(from snapshot: BehaviorSnapshot) -> [String: Double] {
        return [
            "typing_interval_mean": snapshot.typingIntervalMean,
            "typing_interval_cv": snapshot.typingIntervalCV,
            "backspace_ratio": snapshot.backspaceRatio,
            "pause_frequency": snapshot.pauseFrequency,
            "mouse_jitter": snapshot.mouseJitter,
            "mouse_idle_ratio": snapshot.mouseIdleRatio,
            "scroll_direction_changes": snapshot.scrollDirectionChanges,
            "app_switch_rate": snapshot.appSwitchRate,
            "unique_apps": snapshot.uniqueApps,
            "rapid_switch_bursts": snapshot.rapidSwitchBursts,
        ]
    }

    static func createMLFeatureProvider(from snapshot: BehaviorSnapshot) -> MLDictionaryFeatureProvider? {
        let features = extractFeatures(from: snapshot)
        let nsFeatures = features.mapValues { NSNumber(value: $0) } as [String: NSNumber]
        return try? MLDictionaryFeatureProvider(dictionary: nsFeatures)
    }
}
