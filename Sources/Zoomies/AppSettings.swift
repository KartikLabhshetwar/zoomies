import Foundation
import Combine
import ZoomiesCore

/// Single source of truth for user preferences, backed by UserDefaults.
/// Observed by the AppDelegate (to react to changes) and bound by the Settings window.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let minSensitivity = 0.5
    static let maxSensitivity = 2.5

    @Published var source: LoadSource { didSet { defaults.set(source.rawValue, forKey: Keys.source) } }
    @Published var sensitivity: Double { didSet { defaults.set(sensitivity, forKey: Keys.sensitivity) } }
    @Published var showPercentage: Bool { didSet { defaults.set(showPercentage, forKey: Keys.showPct) } }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let source = "loadSource"
        static let sensitivity = "sensitivity"
        static let showPct = "showPercentage"
    }

    private init() {
        source = LoadSource(rawValue: defaults.string(forKey: Keys.source) ?? "") ?? .cpu
        let stored = defaults.double(forKey: Keys.sensitivity)
        sensitivity = stored == 0 ? 1.0 : stored
        showPercentage = defaults.bool(forKey: Keys.showPct)
    }

    /// Apply sensitivity to a raw 0...1 load (clamped). Higher sensitivity → reacts sooner.
    func scaled(_ load: Double) -> Double {
        min(max(load * sensitivity, 0), 1)
    }
}
