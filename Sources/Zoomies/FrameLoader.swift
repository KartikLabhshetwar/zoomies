import AppKit
import CoreGraphics
import ZoomiesCore

enum FrameLoader {
    static let iconHeight: CGFloat = 26
    /// Vertical gait bounce (points) applied to the classic run cycle's flight frame.
    private static let runBounce: CGFloat = 2

    // MARK: - Animation scripts

    // Each entry is (col, row, ticks) in the clean sheet's 32px-pitch grid.
    // row 0 = visual top of the sheet; ticks are counted at 60 Hz.
    //
    // Classic (Neko Archive) row 0 layout:
    //   col 0=sit  1=alert  2=scratchA  3=scratchB  4=tired  6=sleepA  7=sleepB
    //
    // Adryd (oneko.js) layout per nekoFrames CSS-sprite map:
    //   still=(3,3)  alert=(7,3)  scratchSelf=(5,0)/(6,0)
    //   tired=(3,2)  sleeping=(2,0)/(2,1)

    private static let classicScript: [(col: Int, row: Int, ticks: Int)] = [
        (0, 0, 120),                           // sit      2 s
        (1, 0,  30),                           // alert    0.5 s
        (2, 0,   8), (3, 0,   8),             // scratch  ×1
        (2, 0,   8), (3, 0,   8),             // scratch  ×2
        (2, 0,   8), (3, 0,   8),             // scratch  ×3
        (2, 0,   8), (3, 0,   8),             // scratch  ×4
        (2, 0,   8), (3, 0,   8),             // scratch  ×5
        (2, 0,   8), (3, 0,   8),             // scratch  ×6
        (0, 0,  60),                           // sit      1 s
        (4, 0,  60),                           // tired    1 s
        (6, 0,  20), (7, 0,  20),             // sleep    ×1
        (6, 0,  20), (7, 0,  20),             // sleep    ×2
        (6, 0,  20), (7, 0,  20),             // sleep    ×3
        (6, 0,  20), (7, 0,  20),             // sleep    ×4
        (6, 0,  20), (7, 0,  20),             // sleep    ×5
        (6, 0,  20), (7, 0,  20),             // sleep    ×6
        (0, 0,  60),                           // sit      1 s
    ]

    private static let onekoScript: [(col: Int, row: Int, ticks: Int)] = [
        (3, 3, 120),                           // sit      2 s
        (7, 3,  30),                           // alert    0.5 s
        (5, 0,   8), (6, 0,   8),             // scratch  ×1
        (5, 0,   8), (6, 0,   8),             // scratch  ×2
        (5, 0,   8), (6, 0,   8),             // scratch  ×3
        (5, 0,   8), (6, 0,   8),             // scratch  ×4
        (5, 0,   8), (6, 0,   8),             // scratch  ×5
        (5, 0,   8), (6, 0,   8),             // scratch  ×6
        (3, 3,  60),                           // sit      1 s
        (3, 2,  60),                           // tired    1 s
        (2, 0,  20), (2, 1,  20),             // sleep    ×1
        (2, 0,  20), (2, 1,  20),             // sleep    ×2
        (2, 0,  20), (2, 1,  20),             // sleep    ×3
        (2, 0,  20), (2, 1,  20),             // sleep    ×4
        (2, 0,  20), (2, 1,  20),             // sleep    ×5
        (2, 0,  20), (2, 1,  20),             // sleep    ×6
        (3, 3,  60),                           // sit      1 s
    ]

    // MARK: - Public API

    /// Pre-built (image, ticks) animation sequence for the pet — sit, alert, scratch,
    /// tired, sleep, then repeat. Drive by decrementing ticks each 60 Hz frame.
    static func loadSequence(_ animal: Animal) -> [(image: NSImage, ticks: Int)] {
        guard let sheet = loadSheet(animal) else { return [] }
        let script = animal.isClassic ? classicScript : onekoScript
        return script.map { (col, row, ticks) in
            (cropCell(from: sheet, col: col, row: row), ticks)
        }
    }

    /// Two-frame run cycle for both facing directions, with a subtle gait bounce.
    ///
    /// Classic (Neko Archive): row 2, cols 4 & 5 — the side-on run, left-facing in every
    /// classic sheet (dog, fox, chocobo); mirror for the right-facing variant.
    /// oneko (adryd): col 4, rows 2 & 3 = West/left run; mirror for right.
    ///
    /// The classic sheets only ship a dramatic two-pose gallop, which "pops" on a tiny icon
    /// and read as artificial. Lifting the second (extended/flight) frame `runBounce` points
    /// adds a vertical bound so the cycle reads as running, not a flat A/B flip. oneko already
    /// animates cleanly, so it stays full-size to match its reference look.
    ///
    /// Returns `(left:, right:)` so `PetController` can flip facing without re-loading.
    static func loadRunFrames(_ animal: Animal) -> (left: [NSImage], right: [NSImage]) {
        guard let sheet = loadSheet(animal) else { return ([], []) }
        let positions: [(col: Int, row: Int)] = animal.isClassic
            ? [(4, 2), (5, 2)]   // west run — left-facing in all classic sheets
            : [(4, 2), (4, 3)]   // oneko.js West run W:[[-4,-2],[-4,-3]]
        let left: [NSImage]
        if animal.isClassic {
            let spriteH = iconHeight - runBounce
            left = positions.enumerated().map { i, p in
                let rect = CGRect(x: p.col * 32, y: p.row * 32, width: 32, height: 32)
                guard let cell = sheet.cropping(to: rect) else {
                    return NSImage(size: NSSize(width: iconHeight, height: iconHeight))
                }
                // Frame 0 (gather/contact) stays planted; frame 1 (extend/flight) rides higher.
                return retinaImage(cell, contentHeight: spriteH, lift: i == 0 ? 0 : runBounce)
            }
        } else {
            left = positions.map { cropCell(from: sheet, col: $0.col, row: $0.row) }
        }
        let right = left.map { mirrored($0) }
        return (left: left, right: right)
    }

    private static func mirrored(_ image: NSImage) -> NSImage {
        let size = image.size
        let out = NSImage(size: size)
        out.lockFocus()
        let t = NSAffineTransform()
        t.translateX(by: size.width, yBy: 0)
        t.scaleX(by: -1, yBy: 1)
        t.concat()
        image.draw(at: .zero, from: NSRect(origin: .zero, size: size),
                   operation: .copy, fraction: 1)
        out.unlockFocus()
        return out
    }

    /// Sit/idle frame at icon size for the Settings animal-picker thumbnail.
    static func loadIdlePreview(_ animal: Animal) -> NSImage? {
        guard let sheet = loadSheet(animal) else { return nil }
        let (col, row) = animal.isClassic ? (0, 0) : (3, 3)
        return cropCell(from: sheet, col: col, row: row)
    }

    // MARK: - Sheet loading

    private static func loadSheet(_ animal: Animal) -> CGImage? {
        guard let url  = Bundle.main.url(forResource: "\(animal.id)_sheet",
                                          withExtension: "png",
                                          subdirectory: "Sprites"),
              let data = try? Data(contentsOf: url),
              let src  = CGImageSourceCreateWithData(data as CFData, nil) else {
            NSLog("Zoomies: sheet not found — Sprites/\(animal.id)_sheet.png")
            return nil
        }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    // MARK: - Cell extraction & scaling

    private static func cropCell(from sheet: CGImage, col: Int, row: Int) -> NSImage {
        let rect = CGRect(x: col * 32, y: row * 32, width: 32, height: 32)
        if let cell = sheet.cropping(to: rect) {
            return retinaImage(cell)
        }
        return NSImage(size: NSSize(width: iconHeight, height: iconHeight))
    }

    /// Scale a raw CGImage into the menu-bar icon at Retina resolution with
    /// nearest-neighbour interpolation so pixel art stays crisp. The artwork is drawn
    /// `contentHeight` points tall (≤ `iconHeight`) and `lift` points up from the bottom of
    /// an always-`iconHeight`-tall canvas — that headroom is what lets the run cycle bounce
    /// without changing the status item's height. `trailingPad` keeps the pet off the % label.
    static func retinaImage(_ src: CGImage,
                            contentHeight: CGFloat = iconHeight,
                            lift: CGFloat = 0) -> NSImage {
        let trailingPad: CGFloat = 4
        let scale   = NSScreen.main?.backingScaleFactor ?? 2.0
        let aspect  = src.width > 0 ? Double(src.width) / Double(src.height) : 1
        let ptW     = (Double(contentHeight) * aspect).rounded()
        let pxW     = Int((ptW * scale).rounded())
        let pxH     = Int((Double(contentHeight) * scale).rounded())   // artwork height
        let canvasH = Int((Double(iconHeight) * scale).rounded())      // full icon height
        let pxPad   = Int((trailingPad * scale).rounded())
        let pxLift  = Int((Double(lift) * scale).rounded())
        guard pxW > 0, pxH > 0 else {
            return NSImage(size: NSSize(width: ptW + trailingPad, height: Double(iconHeight)))
        }

        let totalPxW = pxW + pxPad
        let ctx = CGContext(data: nil, width: totalPxW, height: canvasH,
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.interpolationQuality = .none
        ctx.clear(CGRect(x: 0, y: 0, width: totalPxW, height: canvasH))
        ctx.draw(src, in: CGRect(x: 0, y: pxLift, width: pxW, height: pxH))   // CG origin = bottom-left

        let totalPtW = ptW + trailingPad
        let out = NSImage(size: NSSize(width: totalPtW, height: Double(iconHeight)))
        if let cg = ctx.makeImage() {
            let rep = NSBitmapImageRep(cgImage: cg)
            rep.size = NSSize(width: totalPtW, height: Double(iconHeight))
            out.addRepresentation(rep)
        }
        return out
    }
}
