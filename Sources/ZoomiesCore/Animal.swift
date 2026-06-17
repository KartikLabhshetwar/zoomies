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
    public static let all: [Animal] = [
        Animal(id: "cat", name: "Cat", frameCount: 5),
        Animal(id: "dog", name: "Dog", frameCount: 4),
        Animal(id: "rabbit", name: "Rabbit", frameCount: 4),
        Animal(id: "horse", name: "Horse", frameCount: 5),
        Animal(id: "parrot", name: "Parrot", frameCount: 10),
    ]

    public static let `default` = all[0]

    public static func animal(withID id: String) -> Animal {
        all.first { $0.id == id } ?? `default`
    }
}
