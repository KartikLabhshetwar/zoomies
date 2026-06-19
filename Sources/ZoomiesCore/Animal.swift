public struct Animal: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let frameCount: Int

    public init(id: String, name: String, frameCount: Int) {
        self.id = id
        self.name = name
        self.frameCount = frameCount
    }

    public func frameName(_ index: Int) -> String { "\(id)_\(index)" }
    public var frameNames: [String] { (0..<frameCount).map(frameName) }
}

public enum AnimalLibrary {
    // The one and only sprite: oneko, the classic "Neko" cat (oneko.js by adryd, MIT).
    // Two frames make up its left-facing run cycle, paced by system load.
    public static let all: [Animal] = [
        Animal(id: "oneko", name: "Oneko", frameCount: 2),
    ]

    public static let `default` = all[0]

    public static func animal(withID id: String) -> Animal {
        all.first { $0.id == id } ?? `default`
    }
}
