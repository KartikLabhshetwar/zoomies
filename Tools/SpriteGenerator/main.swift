import AppKit
import CoreGraphics
import Foundation

// Zoomies sprite importer — multi-animal edition.
//
// Slices each animal's sprite sheet into a left-facing 2-frame run cycle plus an
// idle/sit frame, and writes them as plain PNGs into Sources/Zoomies/Sprites/:
//   <id>_run_0.png, <id>_run_1.png, <id>_idle.png
// FrameLoader picks these up at runtime, scales them to menu-bar height, and mirrors
// them horizontally to produce right-facing frames. Frames are stored facing LEFT.
//
// Two sheet formats are supported:
//   .adryd   — adryd's oneko.gif: 256×128, 8×4 grid of 32×32 cells, no gridlines,
//              transparent background, monochrome line-art. (MIT, © 2022 adryd.)
//   .classic — The Neko Archive sheets: 32×32 cells on a 33px pitch (1px gridlines
//              between cells) over a solid chroma-key background that we strip to
//              transparency. Colored pixel art. (See resources/<id>/LICENSE.)
//
// Per the classic neko sprite map, row 3 holds the side-on left run cycle at columns
// 2 & 3, and (0,0) is the front-facing sit (idle). adryd's own map puts the West run
// at column 4, rows 2 & 3, and the idle sit at (3,3).

enum SheetFormat { case adryd, classic }

struct Skin {
    let id: String
    let sheet: String
    let format: SheetFormat
    let run: [(col: Int, row: Int)]   // left-facing run cycle
    let idle: (col: Int, row: Int)    // resting / sit pose
}

let cellSize = 32
let spritesPath = "Sources/Zoomies/Sprites"

let skins: [Skin] = [
    Skin(id: "oneko",     sheet: "resources/oneko/oneko.gif",         format: .adryd,
         run: [(4, 2), (4, 3)], idle: (3, 3)),
    Skin(id: "dog",       sheet: "resources/dog/dog.png",             format: .classic,
         run: [(4, 1), (5, 1)], idle: (0, 0)),
    Skin(id: "fox",       sheet: "resources/fox/fox.png",             format: .classic,
         run: [(4, 1), (5, 1)], idle: (0, 0)),
    Skin(id: "chocobo",   sheet: "resources/chocobo/chocobo.png",     format: .classic,
         run: [(4, 1), (5, 1)], idle: (0, 0)),
]

func pitch(for format: SheetFormat) -> Int { format == .adryd ? cellSize : cellSize + 1 }

// MARK: - Image processing

func loadCG(_ path: String) -> CGImage {
    guard let data = NSData(contentsOfFile: path),
          let src = CGImageSourceCreateWithData(data, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        fatalError("failed to load \(path)")
    }
    return img
}

/// Draw a CGImage into a fresh premultiplied-RGBA context and hand back the raw bytes.
func rgbaBuffer(_ img: CGImage) -> (ctx: CGContext, ptr: UnsafeMutablePointer<UInt8>, w: Int, h: Int) {
    let w = img.width, h = img.height, bpr = w * 4
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                        bytesPerRow: bpr, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    let ptr = ctx.data!.bindMemory(to: UInt8.self, capacity: bpr * h)
    return (ctx, ptr, w, h)
}

/// Strip the classic sheets' solid chroma-key background to transparency. The key
/// color is detected as the sheet's most common pixel; anything within tolerance of
/// it (including anti-aliased edges and the 1px gridlines) becomes fully transparent.
func removeBackground(_ img: CGImage, tolerance: Int = 70) -> CGImage {
    let (ctx, ptr, w, h) = rgbaBuffer(img)
    // Most-common OPAQUE color = background. (Counting transparent pixels would let
    // their RGB (0,0,0) merge with black outline pixels and beat the real bg — which
    // is exactly what happened with chocobo's pre-transparent sheet.)
    var counts: [UInt32: Int] = [:]
    for i in stride(from: 0, to: w * h * 4, by: 4) where ptr[i + 3] > 200 {
        let key = UInt32(ptr[i]) << 16 | UInt32(ptr[i + 1]) << 8 | UInt32(ptr[i + 2])
        counts[key, default: 0] += 1
    }
    let bg = counts.max { $0.value < $1.value }!.key
    let br = Int((bg >> 16) & 0xff), bgc = Int((bg >> 8) & 0xff), bb = Int(bg & 0xff)
    for i in stride(from: 0, to: w * h * 4, by: 4) {
        let dr = abs(Int(ptr[i]) - br), dg = abs(Int(ptr[i + 1]) - bgc), db = abs(Int(ptr[i + 2]) - bb)
        if dr + dg + db < tolerance {
            ptr[i] = 0; ptr[i + 1] = 0; ptr[i + 2] = 0; ptr[i + 3] = 0
        }
    }
    return ctx.makeImage()!
}

/// Cut one 32×32 cell out of the sheet at the given grid coordinate (top-left origin).
func cutCell(_ sheet: CGImage, col: Int, row: Int, pitch: Int) -> CGImage {
    let rect = CGRect(x: col * pitch, y: row * pitch, width: cellSize, height: cellSize)
    guard let cropped = sheet.cropping(to: rect) else {
        fatalError("crop failed for cell (\(col), \(row)) — sheet is \(sheet.width)×\(sheet.height)")
    }
    return cropped
}

/// Find the shared tight bounding box across the given frames, then crop each to it so
/// the sprite fills the slot and multi-frame cycles stay registered (no jitter).
func cropToBounds(_ images: [CGImage]) -> [CGImage] {
    var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
    for img in images {
        let (ctx, ptr, w, h) = rgbaBuffer(img)
        withExtendedLifetime(ctx) {   // keep the backing buffer alive while we read ptr
            for y in 0..<h {
                for x in 0..<w where ptr[(y * w + x) * 4 + 3] > 10 {
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
        // CoreGraphics origin is bottom-left; image y is flipped relative to pixel y.
        let srcH = img.height
        ctx.draw(img, in: CGRect(x: -minX, y: -(srcH - ch - minY), width: img.width, height: srcH))
        return ctx.makeImage()!
    }
}

/// Flip a frame horizontally. Classic neko sheets draw their side run facing right;
/// we mirror them so every stored frame faces LEFT (the app's canonical facing).
func mirrorHorizontally(_ img: CGImage) -> CGImage {
    let w = img.width, h = img.height
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .none
    ctx.translateBy(x: CGFloat(w), y: 0)
    ctx.scaleBy(x: -1, y: 1)
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("png encode failed")
    }
    try! data.write(to: url)
}

/// Re-tile a sheet into a clean packed PNG — 32×32 cells, no gridlines, transparent
/// background. Writes to resources/<id>/<id>_sheet.png (reference) and to
/// Sources/Zoomies/Sprites/<id>_sheet.png (consumed by the app at runtime).
func exportCleanSheet(_ sheet: CGImage, id: String, format: SheetFormat) {
    let p = pitch(for: format)
    // For adryd (pitch=32, no gridlines): (256+1)/32=8 cols, (128+1)/32=4 rows.
    // For classic (pitch=33, 1px gap): (263+1)/33=8 cols, (164+1)/33=5 rows, etc.
    let cols = (sheet.width + 1) / p
    let rows = (sheet.height + 1) / p
    let outW = cols * cellSize
    let outH = rows * cellSize
    let ctx = CGContext(data: nil, width: outW, height: outH, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.clear(CGRect(x: 0, y: 0, width: outW, height: outH))
    for row in 0..<rows {
        for col in 0..<cols {
            let cell = cutCell(sheet, col: col, row: row, pitch: p)
            // CG contexts have bottom-left origin; row 0 in image space is visual top.
            let destY = CGFloat((rows - 1 - row) * cellSize)
            ctx.draw(cell, in: CGRect(x: CGFloat(col * cellSize), y: destY,
                                      width: CGFloat(cellSize), height: CGFloat(cellSize)))
        }
    }
    guard let out = ctx.makeImage() else { return }
    writePNG(out, to: URL(fileURLWithPath: "resources/\(id)/\(id)_sheet.png"))
    writePNG(out, to: URL(fileURLWithPath: "Sources/Zoomies/Sprites/\(id)_sheet.png"))
    print("  \(outW)×\(outH)px (\(cols)×\(rows)) → Sprites/\(id)_sheet.png")
}

// MARK: - Main

let fm = FileManager.default
try? fm.createDirectory(at: URL(fileURLWithPath: spritesPath), withIntermediateDirectories: true)

for skin in skins {
    var sheet = loadCG(skin.sheet)
    if skin.format == .classic { sheet = removeBackground(sheet) }
    print("\(skin.id):")
    exportCleanSheet(sheet, id: skin.id, format: skin.format)
}
print("Done — \(skins.count) clean sheets written")
