public struct Animal: Equatable, Identifiable {
    public let id: String
    public let name: String
    /// true = Neko Archive layout; false = adryd oneko.js layout.
    public let isClassic: Bool

    public init(id: String, name: String, isClassic: Bool) {
        self.id = id
        self.name = name
        self.isClassic = isClassic
    }
}

public enum AnimalLibrary {
    public static let all: [Animal] = [
        Animal(id: "oneko",     name: "Cat",       isClassic: false),
        Animal(id: "dog",       name: "Dog",       isClassic: true),
        Animal(id: "fox",       name: "Fox",       isClassic: true),
        Animal(id: "chocobo",   name: "Chocobo",   isClassic: true),
    ]

    public static let `default` = all[0]

    public static func animal(withID id: String) -> Animal {
        all.first { $0.id == id } ?? `default`
    }
}
