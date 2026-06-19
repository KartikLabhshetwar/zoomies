public struct PetColor: Equatable, Identifiable {
    public let id: String
    public let displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public struct Animal: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let colors: [PetColor]
    public let defaultColorID: String
    /// Some creatures (monkey, skeleton, totoro) ship no walk_fast cycle; their fast
    /// bucket reuses the run cycle.
    public let hasWalkFast: Bool

    public init(id: String, name: String, colors: [PetColor],
                defaultColorID: String, hasWalkFast: Bool) {
        self.id = id
        self.name = name
        self.colors = colors
        self.defaultColorID = defaultColorID
        self.hasWalkFast = hasWalkFast
    }

    /// The requested color, or the animal's default when that id isn't in its palette.
    public func color(withID id: String) -> PetColor {
        colors.first { $0.id == id }
            ?? colors.first { $0.id == defaultColorID }
            ?? colors[0]
    }
}

public enum PetNaming {
    /// "rubber-duck" -> "Rubber Duck", "socks_black" -> "Socks Black".
    public static func humanize(_ id: String) -> String {
        id.split(whereSeparator: { $0 == "_" || $0 == "-" })
          .map { $0.prefix(1).uppercased() + $0.dropFirst() }
          .joined(separator: " ")
    }
}

public enum AnimalLibrary {
    // Four-legged / bipedal walkers only. Birds, the snake, the snail, the legless mascots
    // (clippy, rocky, zappy, mod, morph, rubber-duck), and crab/monkey/totoro are excluded.
    public static let all: [Animal] = [
        make("deno",        ["green"]),
        make("dog",         ["akita", "black", "brown", "red", "white"]),
        make("fox",         ["red", "white"]),
        make("horse",       ["black", "brown", "magical", "paint_beige", "paint_black",
                             "paint_brown", "socks_beige", "socks_black", "socks_brown",
                             "warrior", "white"]),
        make("panda",       ["black", "brown"]),
        make("rat",         ["brown", "gray", "white"]),
        make("skeleton",    ["blue", "brown", "green", "orange", "pink", "purple",
                             "red", "warrior", "white", "yellow"], hasWalkFast: false),
        make("turtle",      ["green", "orange"]),
        make("vampire",     ["converted", "countess", "girl"], defaultColor: "countess"),
    ]

    public static let `default` = all.first { $0.id == "dog" } ?? all[0]

    public static func animal(withID id: String) -> Animal {
        all.first { $0.id == id } ?? `default`
    }

    /// `defaultColor` defaults to the first listed color (alphabetical), which avoids the
    /// novelty variants (e.g. dog's flaming "red") for every pet except vampire.
    private static func make(_ id: String, _ colors: [String],
                             defaultColor: String? = nil, hasWalkFast: Bool = true) -> Animal {
        Animal(id: id,
               name: PetNaming.humanize(id),
               colors: colors.map { PetColor(id: $0, displayName: PetNaming.humanize($0)) },
               defaultColorID: defaultColor ?? colors[0],
               hasWalkFast: hasWalkFast)
    }
}
