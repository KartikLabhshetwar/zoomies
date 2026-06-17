import AppKit
import CoreGraphics
import Foundation

// Zoomies sprite importer.
//
// Converts source pixel-art PNGs from resources/ into template-rendered asset-catalog
// imagesets, the same pipeline used for the RunCat cat sprite.
//
// Sources and licenses:
//   horse   — RunCat365 (Apache-2.0, runcat-dev/RunCat365), 5 frames, 32×32
//   dog     — AntumDeluge/game-resources fox sprite (CC BY-SA 3.0, Wolf Pack rework),
//             row 3 (west/left) of fox-NESW.png, 3 source frames → 4-frame cycle
//   rabbit  — AntumDeluge/game-resources rabbit48 (CC BY 3.0, Stephen Challener/Redshrike),
//             row 1 (west/left), 3 source frames → 4-frame cycle
//   parrot  — RunCat365 (Apache-2.0, runcat-dev/RunCat365), 10 frames, 32×32
//
// NOTE: the cat frames are in the asset catalog already (RunCat, Apache-2.0). Do not
// re-generate them here — the cleanup below skips any imageset not in generatedIDs.

struct AnimalImport {
    let id: String
    let sourcePaths: [String]
    let frameSequence: [Int]
    let conversion: Conversion

    enum Conversion {
        // Already-dark sprites (horse): dark body stays opaque, light areas → transparent.
        case luminanceToAlpha
        // Colored sprites (dog/rabbit/penguin): any non-transparent pixel → full black opaque.
        case alphaThreshold
    }
}

let resourcesDir = "resources"
let animals: [AnimalImport] = [
    AnimalImport(
        id: "horse",
        sourcePaths: (0..<5).map { "\(resourcesDir)/horse/horse_\($0).png" },
        frameSequence: [0, 1, 2, 3, 4],
        conversion: .luminanceToAlpha
    ),
    AnimalImport(
        id: "dog",
        sourcePaths: (0..<3).map { "\(resourcesDir)/dog/dog_\($0).png" },
        frameSequence: [0, 1, 2, 1],
        conversion: .alphaThreshold
    ),
    AnimalImport(
        id: "rabbit",
        sourcePaths: (0..<3).map { "\(resourcesDir)/rabbit/rabbit_\($0).png" },
        frameSequence: [0, 1, 2, 1],
        conversion: .alphaThreshold
    ),
    AnimalImport(
        id: "parrot",
        sourcePaths: (0..<10).map { "\(resourcesDir)/parrot/parrot_\($0).png" },
        frameSequence: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
        conversion: .luminanceToAlpha   // RunCat365 style: dark body stays, light areas → transparent
    ),
]

// MARK: - Image processing

func loadCG(_ path: String) -> CGImage {
    guard let data = NSData(contentsOfFile: path),
          let src = CGImageSourceCreateWithData(data, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        fatalError("failed to load \(path)")
    }
    return img
}

func toSilhouette(_ src: CGImage, conversion: AnimalImport.Conversion) -> CGImage {
    let w = src.width, h = src.height, bpr = w * 4
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                        bytesPerRow: bpr, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.draw(src, in: CGRect(x: 0, y: 0, width: w, height: h))
    let ptr = ctx.data!.bindMemory(to: UInt8.self, capacity: bpr * h)
    for i in stride(from: 0, to: bpr * h, by: 4) {
        let a = ptr[i + 3]
        switch conversion {
        case .luminanceToAlpha:
            if a == 0 { ptr[i] = 0; ptr[i+1] = 0; ptr[i+2] = 0; continue }
            let rf = Double(ptr[i])   * 255 / Double(a)
            let gf = Double(ptr[i+1]) * 255 / Double(a)
            let bf = Double(ptr[i+2]) * 255 / Double(a)
            let lum = (0.299 * rf + 0.587 * gf + 0.114 * bf) / 255
            let na = UInt8(max(0, min(255, (Double(a) * (1.0 - lum)).rounded())))
            ptr[i] = 0; ptr[i+1] = 0; ptr[i+2] = 0; ptr[i+3] = na
        case .alphaThreshold:
            if a < 20 { ptr[i] = 0; ptr[i+1] = 0; ptr[i+2] = 0; ptr[i+3] = 0 }
            else       { ptr[i] = 0; ptr[i+1] = 0; ptr[i+2] = 0; ptr[i+3] = 255 }
        }
    }
    return ctx.makeImage()!
}

// Find shared tight bounding box across all frames, then crop each to that box.
func cropToBounds(_ images: [CGImage]) -> [CGImage] {
    var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
    for img in images {
        let w = img.width, h = img.height, bpr = w * 4
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: bpr, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        let ptr = ctx.data!.bindMemory(to: UInt8.self, capacity: bpr * h)
        for y in 0..<h {
            for x in 0..<w {
                let a = ptr[(y * w + x) * 4 + 3]
                if a > 10 {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
    }
    guard maxX >= minX, maxY >= minY else { return images }
    let cw = maxX - minX + 1, ch = maxY - minY + 1
    return images.map { img in
        let ctx = CGContext(data: nil, width: cw, height: ch, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.clear(CGRect(x: 0, y: 0, width: cw, height: ch))
        // CoreGraphics origin is bottom-left; img y-axis is flipped relative to pixel y
        let srcH = img.height
        ctx.draw(img, in: CGRect(x: -minX, y: -(srcH - ch - minY), width: img.width, height: srcH))
        return ctx.makeImage()!
    }
}

func scale(_ src: CGImage, toHeight targetH: Int) -> CGImage {
    let aspect = Double(src.width) / Double(src.height)
    let w = max(1, Int((Double(targetH) * aspect).rounded()))
    let ctx = CGContext(data: nil, width: w, height: targetH, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .none
    ctx.clear(CGRect(x: 0, y: 0, width: w, height: targetH))
    ctx.draw(src, in: CGRect(x: 0, y: 0, width: w, height: targetH))
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("png encode failed")
    }
    try! data.write(to: url)
}

// MARK: - Main

let fm = FileManager.default
let assets = URL(fileURLWithPath: "Sources/Zoomies/Assets.xcassets")
try? fm.createDirectory(at: assets, withIntermediateDirectories: true)

// Clean out only THIS importer's imagesets (leave hand-placed cat frames).
let generatedIDs = Set(animals.map { $0.id })
if let items = try? fm.contentsOfDirectory(at: assets, includingPropertiesForKeys: nil) {
    for item in items where item.pathExtension == "imageset" {
        let base = item.deletingPathExtension().lastPathComponent
        let id = base.split(separator: "_").dropLast().joined(separator: "_")
        if generatedIDs.contains(id) { try? fm.removeItem(at: item) }
    }
}
try! #"{"info":{"author":"xcode","version":1}}"#
    .write(to: assets.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

for animal in animals {
    // Load + convert all source frames
    let sources = animal.sourcePaths.map { loadCG($0) }
    let silhouettes = sources.map { toSilhouette($0, conversion: animal.conversion) }
    // Build the frame sequence (e.g. [0,1,2,1] from 3 sources → 4 frames)
    let sequenced = animal.frameSequence.map { silhouettes[$0] }
    // Crop all frames to their shared tight bounding box
    let cropped = cropToBounds(sequenced)

    for (f, img) in cropped.enumerated() {
        let name = "\(animal.id)_\(f)"
        let dir = assets.appendingPathComponent("\(name).imageset")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        // 1x: pixel-perfect (nearest-neighbour, no scaling up small sprites)
        let img1x = scale(img, toHeight: img.height)
        let img2x = scale(img, toHeight: img.height * 2)
        writePNG(img1x, to: dir.appendingPathComponent("\(name)_1x.png"))
        writePNG(img2x, to: dir.appendingPathComponent("\(name)_2x.png"))
        let contents = """
        {"images":[{"idiom":"mac","scale":"1x","filename":"\(name)_1x.png"},\
        {"idiom":"mac","scale":"2x","filename":"\(name)_2x.png"}],\
        "info":{"author":"xcode","version":1},\
        "properties":{"template-rendering-intent":"template"}}
        """
        try! contents.write(to: dir.appendingPathComponent("Contents.json"),
                            atomically: true, encoding: .utf8)
    }
    let frame0 = cropped[0]
    print("\(animal.id): \(cropped.count) frames, \(frame0.width)×\(frame0.height)px at 1x")
}
print("Imported \(animals.count) animals into \(assets.path)")
