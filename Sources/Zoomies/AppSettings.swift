import Foundation
import Combine
import ZoomiesCore

/// Single source of truth for user preferences, backed by UserDefaults.
/// Observed by the AppDelegate (to react to changes) and bound by the Settings window.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let minSpeed = 0.5
    static let maxSpeed = 2.5

    @Published var source: LoadSource { didSet { defaults.set(source.rawValue, forKey: Keys.source) } }
    /// Direct run-speed multiplier applied to the whole load→fps curve (visible even at idle).
    @Published var speed: Double { didSet { defaults.set(speed, forKey: Keys.speed) } }
    @Published var showPercentage: Bool { didSet { defaults.set(showPercentage, forKey: Keys.showPct) } }
    /// Which animal roams the menu bar (an AnimalLibrary id).
    @Published var animalID: String { didSet { defaults.set(animalID, forKey: Keys.animalID) } }
    /// Which color variant of the selected animal roams the menu bar.
    @Published var colorID: String { didSet { defaults.set(colorID, forKey: Keys.colorID) } }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let source = "loadSource"
        static let speed = "speed"
        static let showPct = "showPercentage"
        static let animalID = "animalID"
        static let colorID = "colorID"
    }

    private init() {
        source = LoadSource(rawValue: defaults.string(forKey: Keys.source) ?? "") ?? .cpu
        let storedSpeed = defaults.double(forKey: Keys.speed)
        speed = storedSpeed == 0 ? 1.0 : storedSpeed
        showPercentage = defaults.bool(forKey: Keys.showPct)
        let storedAnimal = defaults.string(forKey: Keys.animalID)
        let resolvedAnimalID = AnimalLibrary.all.contains { $0.id == storedAnimal }
            ? storedAnimal! : AnimalLibrary.default.id
        animalID = resolvedAnimalID
        let animal = AnimalLibrary.animal(withID: resolvedAnimalID)
        let storedColor = defaults.string(forKey: Keys.colorID)
        colorID = animal.colors.contains { $0.id == storedColor } ? storedColor! : animal.defaultColorID
    }
}
