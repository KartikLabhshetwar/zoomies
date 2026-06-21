public struct PetColor: Equatable, Identifiable {
    public let id: String
    public let displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

/// 32px-grid Neko sprite-sheet layouts (the classic 1.0 pets).
public enum SheetLayout: Equatable { case classic, oneko }

/// Where a pet's frames come from: per-state webpets GIFs, or a packed Neko sprite sheet.
public enum SpriteSource: Equatable {
    case gif
    case sheet(resource: String, layout: SheetLayout)
}

public struct Animal: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let colors: [PetColor]
    public let defaultColorID: String
    /// Some creatures (skeleton, and the sheet pets) ship no walk_fast cycle; their fast
    /// bucket reuses the run cycle.
    public let hasWalkFast: Bool
    /// GIF (webpets) or a packed sprite sheet (classic Cat/Dalmatian).
    public let source: SpriteSource
    /// True if the source art faces right (webpets); false for the left-facing Neko sheets.
    /// The loader mirrors accordingly so the pet faces the way the cursor moves.
    public let facesRight: Bool

    public init(id: String, name: String, colors: [PetColor],
                defaultColorID: String, hasWalkFast: Bool,
                source: SpriteSource = .gif, facesRight: Bool = true) {
        self.id = id
        self.name = name
        self.colors = colors
        self.defaultColorID = defaultColorID
        self.hasWalkFast = hasWalkFast
        self.source = source
        self.facesRight = facesRight
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
    // Four-legged / bipedal walkers only. Birds, snake, snail, the legless mascots (clippy,
    // rocky, zappy, mod, morph, rubber-duck), and crab/monkey/totoro/turtle are excluded.
    public static let all: [Animal] = [
        // Classic 1.0 sprite-sheet pets.
        makeSheet("cat", "Cat", "White", resource: "oneko_sheet", layout: .oneko),
        makeSheet("dalmatian", "Dalmatian", "Spotted", resource: "dalmatian_sheet", layout: .classic),
        // webpets GIF pets.
        make("deno",        ["green"]),
        make("dog",         ["akita", "black", "brown", "red", "white"]),
        make("fox",         ["red", "white"]),
        make("horse",       ["black", "brown", "magical", "paint_beige", "paint_black",
                             "paint_brown", "socks_beige", "socks_black", "socks_brown",
                             "warrior", "white"]),
        make("panda",       ["black", "brown"]),
        make("skeleton",    ["blue", "brown", "green", "orange", "pink", "purple",
                             "red", "warrior", "white", "yellow"], hasWalkFast: false),
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

    /// A classic Neko sprite-sheet pet: one color, left-facing art, no distinct walk_fast.
    private static func makeSheet(_ id: String, _ name: String, _ colorName: String,
                                  resource: String, layout: SheetLayout) -> Animal {
        Animal(id: id, name: name,
               colors: [PetColor(id: "classic", displayName: colorName)],
               defaultColorID: "classic", hasWalkFast: false,
               source: .sheet(resource: resource, layout: layout), facesRight: false)
    }
}
