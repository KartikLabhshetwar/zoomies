import AppKit
import ImageIO
import ZoomiesCore

/// Decodes the webpets GIFs for one pet+color into menu-bar-sized animation frames.
///
/// Each state (idle/walk/walk_fast/run) is a separate GIF with its own frame count and
/// per-frame durations. The frames of all states are registered to a single scale and a
/// shared bottom-center baseline so the pet never jumps or resizes when its gait changes,
/// and within a state every frame shares one bounding box so the body doesn't wobble as
/// limbs extend. Frames are pre-mirrored for right-facing (the art faces left).
enum FrameLoader {
    /// Height in points the tallest frame is scaled to. The menu bar is ~22pt; shorter
    /// states render smaller and stay planted on the shared baseline.
    static let iconHeight: CGFloat = 22
    /// Hard cap on rendered width so very wide creatures (snake, horse) stay tidy next to
    /// the percentage label.
    static let maxWidth: CGFloat = 46
    /// Gap (points) kept on the trailing edge so the sprite doesn't hug the % label.
    static let trailingPad: CGFloat = 4

    struct StateClip {
        let left: [NSImage]
        let right: [NSImage]
        let durations: [Double]
    }
    struct PetClips {
        let states: [PetState: StateClip]
        let thumbnail: NSImage?
    }

    private static let stateFile: [PetState: String] = [
        .idle: "idle", .walk: "walk", .walkFast: "walk_fast", .run: "run"
    ]

    // MARK: - Public API

    /// Decode every state's GIF for one pet+color and render registered, pre-mirrored frames.
    static func loadClips(_ animal: Animal, colorID: String) -> PetClips {
        let color = animal.color(withID: colorID).id

        // 1. Decode raw frames + durations per state (walkFast falls back to run when absent),
        //    and the per-state union of frame content boxes.
        struct Raw { let frames: [CGImage]; let durations: [Double]; let box: Box }
        var raw: [PetState: Raw] = [:]
        for state in PetState.allCases {
            var key = state
            if state == .walkFast, !animal.hasWalkFast { key = .run }
            guard let url = gifURL(pet: animal.id, color: color, state: stateFile[key]!) else { continue }
            let decoded = decodeGIF(url)
            guard !decoded.frames.isEmpty else { continue }
            let box = unionBox(decoded.frames.map(contentBox))
            raw[state] = Raw(frames: decoded.frames, durations: decoded.durations, box: box)
        }
        guard !raw.isEmpty else {
            return PetClips(states: [:], thumbnail: loadThumbnail(animal, colorID: colorID))
        }

        // 2. One scale + canvas across ALL states: tallest content fills iconHeight, with a
        //    width cap so wide pets don't sprawl.
        let backing = NSScreen.main?.backingScaleFactor ?? 2
        let maxH = CGFloat(raw.values.map { $0.box.h }.max() ?? 1)
        let maxW = CGFloat(raw.values.map { $0.box.w }.max() ?? 1)
        let scale = min((iconHeight * backing) / max(maxH, 1),
                        (maxWidth * backing) / max(maxW, 1))
        let canvasHpx = Int((iconHeight * backing).rounded())
        let contentWpx = Int((maxW * scale).rounded())
        let padPx = Int((trailingPad * backing).rounded())
        let canvasWpx = max(contentWpx + padPx, 1)
        let ptSize = NSSize(width: CGFloat(canvasWpx) / backing, height: iconHeight)

        // 3. Render each frame against its state's shared box; mirror for right-facing.
        var states: [PetState: StateClip] = [:]
        for (state, r) in raw {
            let left = r.frames.map { f in
                render(f, box: r.box, scale: scale,
                       canvasWpx: canvasWpx, canvasHpx: canvasHpx,
                       contentWpx: contentWpx, ptSize: ptSize)
            }
            let right = left.map { mirrored($0) }
            states[state] = StateClip(left: left, right: right, durations: r.durations)
        }
        return PetClips(states: states, thumbnail: loadThumbnail(animal, colorID: colorID))
    }

    /// Picker thumbnail: prefer the designed `icon_<color>.png`; otherwise show the actual
    /// first idle frame (so color swatches always reflect the real color); finally fall back
    /// to the pet's generic icon.
    static func loadThumbnail(_ animal: Animal, colorID: String) -> NSImage? {
        let color = animal.color(withID: colorID).id
        if let url = Bundle.main.url(forResource: "icon_\(color)", withExtension: "png",
                                     subdirectory: "Pets/\(animal.id)"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        if let idle = idleFrameThumbnail(pet: animal.id, color: color) {
            return idle
        }
        if let url = Bundle.main.url(forResource: "icon", withExtension: "png",
                                     subdirectory: "Pets/\(animal.id)") {
            return NSImage(contentsOf: url)
        }
        return nil
    }

    // MARK: - GIF decode

    private static func gifURL(pet: String, color: String, state: String) -> URL? {
        Bundle.main.url(forResource: "\(color)_\(state)", withExtension: "gif",
                        subdirectory: "Pets/\(pet)")
    }

    private static func decodeGIF(_ url: URL) -> (frames: [CGImage], durations: [Double]) {
        guard let data = try? Data(contentsOf: url),
              let src = CGImageSourceCreateWithData(data as CFData, nil) else { return ([], []) }
        var frames: [CGImage] = []
        var durations: [Double] = []
        for i in 0..<CGImageSourceGetCount(src) {
            guard let img = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
            frames.append(img)
            let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any]
            let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let unclamped = gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double
            let clamped = gif?[kCGImagePropertyGIFDelayTime] as? Double
            let d = (unclamped.flatMap { $0 > 0 ? $0 : nil }) ?? clamped ?? 0.125
            durations.append(d < 0.02 ? 0.125 : d)
        }
        return (frames, durations)
    }

    // MARK: - Registration / rendering

    /// Tight alpha bounding box in CoreGraphics bottom-left pixel coordinates:
    /// (x from left, y from bottom, w, h).
    private struct Box { let x: Int; let y: Int; let w: Int; let h: Int }

    private static func contentBox(_ img: CGImage) -> Box {
        let w = img.width, h = img.height, bpr = w * 4
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: bpr, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return Box(x: 0, y: 0, w: w, h: h)
        }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return Box(x: 0, y: 0, w: w, h: h) }
        let p = data.bindMemory(to: UInt8.self, capacity: bpr * h)
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            for x in 0..<w where p[(y * w + x) * 4 + 3] > 10 {
                if x < minX { minX = x }; if x > maxX { maxX = x }
                if y < minY { minY = y }; if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return Box(x: 0, y: 0, w: w, h: h) }
        return Box(x: minX, y: minY, w: maxX - minX + 1, h: maxY - minY + 1)
    }

    /// Smallest box covering every frame's content, so all frames of a state share one
    /// placement (no horizontal wobble as limbs extend).
    private static func unionBox(_ boxes: [Box]) -> Box {
        guard let first = boxes.first else { return Box(x: 0, y: 0, w: 1, h: 1) }
        var minX = first.x, minY = first.y
        var maxX = first.x + first.w, maxY = first.y + first.h
        for b in boxes.dropFirst() {
            minX = min(minX, b.x); minY = min(minY, b.y)
            maxX = max(maxX, b.x + b.w); maxY = max(maxY, b.y + b.h)
        }
        return Box(x: minX, y: minY, w: maxX - minX, h: maxY - minY)
    }

    /// Draw `img` (scaled) into a fixed canvas so its `box` sits on the baseline (y=0) and is
    /// horizontally centered within the content region. All bottom-left coords — no flips.
    private static func render(_ img: CGImage, box: Box, scale: CGFloat,
                              canvasWpx: Int, canvasHpx: Int, contentWpx: Int,
                              ptSize: NSSize) -> NSImage {
        let targetLeft = (CGFloat(contentWpx) - CGFloat(box.w) * scale) / 2
        let drawX = targetLeft - CGFloat(box.x) * scale
        let drawY = -CGFloat(box.y) * scale
        guard let ctx = CGContext(data: nil, width: canvasWpx, height: canvasHpx,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return NSImage(size: ptSize)
        }
        ctx.interpolationQuality = .high   // smooth downscale of mid-res pixel art
        ctx.clear(CGRect(x: 0, y: 0, width: canvasWpx, height: canvasHpx))
        ctx.draw(img, in: CGRect(x: drawX, y: drawY,
                                 width: CGFloat(img.width) * scale,
                                 height: CGFloat(img.height) * scale))
        let out = NSImage(size: ptSize)
        if let cg = ctx.makeImage() {
            let rep = NSBitmapImageRep(cgImage: cg)
            rep.size = ptSize
            out.addRepresentation(rep)
        }
        return out
    }

    private static func idleFrameThumbnail(pet: String, color: String) -> NSImage? {
        guard let url = gifURL(pet: pet, color: color, state: "idle"),
              let data = try? Data(contentsOf: url),
              let src = CGImageSourceCreateWithData(data as CFData, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        let box = contentBox(img)
        // contentBox is bottom-left; cropping(to:) wants top-left.
        let rect = CGRect(x: box.x, y: img.height - box.y - box.h, width: box.w, height: box.h)
        let cropped = img.cropping(to: rect) ?? img
        return NSImage(cgImage: cropped, size: NSSize(width: box.w, height: box.h))
    }

    private static func mirrored(_ image: NSImage) -> NSImage {
        let size = image.size
        let out = NSImage(size: size)
        out.lockFocus()
        let t = NSAffineTransform()
        t.translateX(by: size.width, yBy: 0)
        t.scaleX(by: -1, yBy: 1)
        t.concat()
        image.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1)
        out.unlockFocus()
        return out
    }
}
