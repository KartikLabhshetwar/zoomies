import AppKit
import CoreGraphics
import Foundation

// Zoomies sprite importer — oneko edition.
//
// Slices the oneko.gif sprite sheet into the cat's left-facing (west) run cycle and
// writes them as COLOR asset-catalog imagesets used by the menu-bar animation.
//
// Source & license:
//   oneko.gif — oneko.js by adryd (MIT, © 2022 adryd). The classic "Neko" desktop pet.
//               256×128 sheet = an 8×4 grid of 32×32 cells. Per the oneko.js sprite map,
//               the West/left run is `W: [[-4,-2],[-4,-3]]` → grid column 4, rows 2 and 3.
//
// Unlike the previous (multi-animal) importer, frames are kept in full color — no
// silhouette/template conversion — so FrameLoader renders the cat with its real pixels.

let sheetPath = "resources/oneko/oneko.gif"
let assetsPath = "Sources/Zoomies/Assets.xcassets"
let spriteID = "oneko"
let cellSize = 32
// (column, row) of each run frame in the 32px grid — oneko's West/left run cycle.
let runFrames: [(col: Int, row: Int)] = [(4, 2), (4, 3)]

// MARK: - Image processing

func loadCG(_ path: String) -> CGImage {
    guard let data = NSData(contentsOfFile: path),
          let src = CGImageSourceCreateWithData(data, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        fatalError("failed to load \(path)")
    }
    return img
}

// Cut one 32×32 cell out of the sprite sheet (top-left origin pixel coordinates).
func cutCell(_ sheet: CGImage, col: Int, row: Int) -> CGImage {
    let rect = CGRect(x: col * cellSize, y: row * cellSize, width: cellSize, height: cellSize)
    guard let cropped = sheet.cropping(to: rect) else {
        fatalError("crop failed for cell (\(col), \(row)) — sheet is \(sheet.width)×\(sheet.height)")
    }
    return cropped
}

// Find the shared tight bounding box across all frames, then crop each to it so the
// cat fills the menu-bar slot and the two frames stay registered (no jitter).
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
        // CoreGraphics origin is bottom-left; img y-axis is flipped relative to pixel y.
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
    ctx.interpolationQuality = .none   // nearest-neighbour keeps the pixel art crisp
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
let assets = URL(fileURLWithPath: assetsPath)
try? fm.createDirectory(at: assets, withIntermediateDirectories: true)

let sheet = loadCG(sheetPath)
let frames = cropToBounds(runFrames.map { cutCell(sheet, col: $0.col, row: $0.row) })

for (f, img) in frames.enumerated() {
    let name = "\(spriteID)_\(f)"
    let dir = assets.appendingPathComponent("\(name).imageset")
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    // 1x: native cropped size. 2x: doubled (nearest-neighbour) for retina menu bars.
    let img1x = scale(img, toHeight: img.height)
    let img2x = scale(img, toHeight: img.height * 2)
    writePNG(img1x, to: dir.appendingPathComponent("\(name)_1x.png"))
    writePNG(img2x, to: dir.appendingPathComponent("\(name)_2x.png"))
    // Color sprite: render as "original" (NOT a template silhouette).
    let contents = """
    {"images":[{"idiom":"mac","scale":"1x","filename":"\(name)_1x.png"},\
    {"idiom":"mac","scale":"2x","filename":"\(name)_2x.png"}],\
    "info":{"author":"xcode","version":1},\
    "properties":{"template-rendering-intent":"original"}}
    """
    try! contents.write(to: dir.appendingPathComponent("Contents.json"),
                        atomically: true, encoding: .utf8)
    print("\(name): \(img.width)×\(img.height)px at 1x")
}
print("Imported \(frames.count) oneko frames into \(assets.path)")
