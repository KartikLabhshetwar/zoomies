// Usage: swift Tools/ImportPets/main.swift <webpets-checkout> <dest-dir>
// Copies the idle/walk/walk_fast/run GIFs + icon PNGs + license for every color variant
// from a webpets checkout into the app's bundled Pets folder, and prints a roster summary
// so the hand-written AnimalLibrary can be cross-checked.
import Foundation

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("usage: import <webpetsRoot> <destDir>\n".utf8))
    exit(2)
}
let media = URL(fileURLWithPath: args[1]).appendingPathComponent("public/media")
let dest  = URL(fileURLWithPath: args[2])
let fm = FileManager.default
let states = ["idle", "walk", "walk_fast", "run"]
// Skip non-pet folders and creatures that don't walk on legs (birds, snake, snail, and the
// legless mascots) — Zoomies only ships leg-walkers.
let skip: Set<String> = [
    "background", "icon", "walkers_wide",
    "chicken", "cockatiel", "snake", "snail", "morph",
    "clippy", "rocky", "zappy", "rubber-duck", "mod",
]

try? fm.createDirectory(at: dest, withIntermediateDirectories: true)
var report: [(String, [String], Bool)] = []   // pet, colors, hasWalkFast

for pet in (try fm.contentsOfDirectory(atPath: media.path)).sorted() where !skip.contains(pet) {
    let petSrc = media.appendingPathComponent(pet)
    var isDir: ObjCBool = false
    guard fm.fileExists(atPath: petSrc.path, isDirectory: &isDir), isDir.boolValue else { continue }
    let files = (try? fm.contentsOfDirectory(atPath: petSrc.path)) ?? []
    let colors = files.filter { $0.hasSuffix("_idle_8fps.gif") }
                      .map { String($0.dropLast("_idle_8fps.gif".count)) }
                      .sorted()
    guard !colors.isEmpty else { continue }

    let petDst = dest.appendingPathComponent(pet)
    try? fm.createDirectory(at: petDst, withIntermediateDirectories: true)
    var hasWalkFast = true

    for color in colors {
        for state in states {
            let src = petSrc.appendingPathComponent("\(color)_\(state)_8fps.gif")
            if fm.fileExists(atPath: src.path) {
                let dst = petDst.appendingPathComponent("\(color)_\(state).gif")
                try? fm.removeItem(at: dst)
                try? fm.copyItem(at: src, to: dst)
            } else if state == "walk_fast" {
                hasWalkFast = false
            }
        }
        let icon = petSrc.appendingPathComponent("icon_\(color).png")
        if fm.fileExists(atPath: icon.path) {
            let dst = petDst.appendingPathComponent("icon_\(color).png")
            try? fm.removeItem(at: dst)
            try? fm.copyItem(at: icon, to: dst)
        }
    }
    // Generic per-pet icon — the thumbnail fallback for colors with no icon_<color>.png.
    let genericIcon = petSrc.appendingPathComponent("icon.png")
    if fm.fileExists(atPath: genericIcon.path) {
        let dst = petDst.appendingPathComponent("icon.png")
        try? fm.removeItem(at: dst)
        try? fm.copyItem(at: genericIcon, to: dst)
    }
    for lic in ["license.txt", "LICENSE", "license"] {
        let s = petSrc.appendingPathComponent(lic)
        if fm.fileExists(atPath: s.path) {
            let d = petDst.appendingPathComponent("license.txt")
            try? fm.removeItem(at: d)
            try? fm.copyItem(at: s, to: d)
            break
        }
    }
    report.append((pet, colors, hasWalkFast))
}

print("Imported \(report.count) pets:")
for (pet, colors, fast) in report {
    print("  \(pet): \(colors.count) colors\(fast ? "" : "  (no walk_fast)")")
}
