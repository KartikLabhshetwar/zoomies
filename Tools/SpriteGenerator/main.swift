import AppKit
import CoreGraphics
import Foundation

// MARK: - Config

enum Gait { case gallop, bound }
enum Ear { case pointy, floppy, longUp }
enum Tail { case longCurved, shortUp, puff, flowing }

struct AnimalConfig {
    let id: String
    let bodyW: Double   // fraction of canvas width
    let bodyH: Double   // fraction of canvas height
    let headR: Double   // fraction of canvas height
    let legLen: Double  // fraction of canvas height
    let lineW: Double   // leg thickness in points
    let ear: Ear
    let tail: Tail
    let gait: Gait
    let mane: Bool      // horse: long neck + mane + muzzle
}

let frameCount = 6
let canvasW = 28.0
let canvasH = 22.0

let animals: [AnimalConfig] = [
    AnimalConfig(id: "cat",    bodyW: 0.46, bodyH: 0.26, headR: 0.13, legLen: 0.30, lineW: 2.0, ear: .pointy, tail: .longCurved, gait: .gallop, mane: false),
    AnimalConfig(id: "dog",    bodyW: 0.50, bodyH: 0.30, headR: 0.15, legLen: 0.30, lineW: 2.4, ear: .floppy, tail: .shortUp,    gait: .gallop, mane: false),
    AnimalConfig(id: "rabbit", bodyW: 0.40, bodyH: 0.32, headR: 0.15, legLen: 0.24, lineW: 2.2, ear: .longUp, tail: .puff,       gait: .bound,  mane: false),
    AnimalConfig(id: "horse",  bodyW: 0.60, bodyH: 0.30, headR: 0.13, legLen: 0.42, lineW: 2.6, ear: .pointy, tail: .flowing,    gait: .gallop, mane: true),
]

let black = CGColor(red: 0, green: 0, blue: 0, alpha: 1)

// MARK: - Drawing

func render(_ cfg: AnimalConfig, frame: Int, scale: Double) -> CGImage {
    let w = Int(canvasW * scale), h = Int(canvasH * scale)
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.scaleBy(x: scale, y: scale)
    ctx.setFillColor(black)
    ctx.setStrokeColor(black)
    ctx.setLineCap(.round)

    let cycle = Double(frame) / Double(frameCount) * 2 * .pi
    let bodyW = cfg.bodyW * canvasW
    let bodyH = cfg.bodyH * canvasH
    let legLen = cfg.legLen * canvasH
    let headR = cfg.headR * canvasH
    let groundY = 2.0
    let bob = 0.7 * sin(2 * cycle)
    let hipY = groundY + legLen + bob
    let bodyCX = canvasW * 0.42
    let bodyCY = hipY + bodyH * 0.35
    var headCX = bodyCX + bodyW / 2 + headR * 0.2
    var headCY = bodyCY + bodyH * 0.25
    if cfg.mane {                     // horse: head raised and forward on a long neck
        headCX += headR * 0.7
        headCY += bodyH * 0.5
    }

    // Legs (behind body)
    func leg(_ hipX: Double, _ phase: Double) {
        let swing = sin(cycle + phase)
        let lift = max(0, sin(cycle + phase + .pi / 2))
        let footX = hipX + swing * (bodyW * 0.16)
        let footY = groundY + lift * (legLen * 0.55)
        ctx.setLineWidth(cfg.lineW)
        ctx.move(to: CGPoint(x: hipX, y: hipY))
        ctx.addLine(to: CGPoint(x: footX, y: footY))
        ctx.strokePath()
    }
    let hipFront = bodyCX + bodyW * 0.28
    let hipBack  = bodyCX - bodyW * 0.28
    switch cfg.gait {
    case .gallop:
        leg(hipFront, 0); leg(hipFront - 1.5, .pi)
        leg(hipBack, .pi / 2); leg(hipBack + 1.5, 3 * .pi / 2)
    case .bound:
        leg(hipFront, 0); leg(hipFront - 1.2, 0.4)
        leg(hipBack, .pi); leg(hipBack + 1.2, .pi + 0.4)
    }

    // Body
    ctx.fillEllipse(in: CGRect(x: bodyCX - bodyW / 2, y: bodyCY - bodyH / 2, width: bodyW, height: bodyH))
    // Neck
    if cfg.mane {
        // long neck rising to the raised head (horse)
        ctx.setLineWidth(bodyH * 0.62)
        ctx.move(to: CGPoint(x: bodyCX + bodyW * 0.20, y: bodyCY))
        ctx.addLine(to: CGPoint(x: headCX - headR * 0.4, y: headCY - headR * 0.3))
        ctx.strokePath()
    } else {
        ctx.fill(CGRect(x: bodyCX + bodyW * 0.2, y: bodyCY, width: bodyW * 0.35, height: bodyH * 0.5))
    }
    // Head
    ctx.fillEllipse(in: CGRect(x: headCX - headR, y: headCY - headR, width: headR * 2, height: headR * 2))
    // Horse muzzle + mane
    if cfg.mane {
        // muzzle: snout pointing forward and slightly down
        ctx.fillEllipse(in: CGRect(x: headCX + headR * 0.2, y: headCY - headR * 0.85,
                                   width: headR * 1.5, height: headR * 1.05))
        // mane: filled wedge down the back of the neck
        ctx.beginPath()
        ctx.move(to: CGPoint(x: headCX - headR * 0.2, y: headCY + headR * 1.1))
        ctx.addLine(to: CGPoint(x: bodyCX + bodyW * 0.30, y: bodyCY + bodyH * 0.55))
        ctx.addLine(to: CGPoint(x: bodyCX + bodyW * 0.14, y: bodyCY + bodyH * 0.15))
        ctx.addLine(to: CGPoint(x: headCX - headR * 0.55, y: headCY + headR * 0.1))
        ctx.closePath()
        ctx.fillPath()
    }
    // Ears
    drawEar(ctx, cfg.ear, headCX, headCY + headR * 0.7, headR)
    // Tail
    drawTail(ctx, cfg.tail, bodyCX - bodyW / 2, bodyCY, cfg.lineW, cycle)

    return ctx.makeImage()!
}

func drawEar(_ ctx: CGContext, _ ear: Ear, _ cx: Double, _ cy: Double, _ r: Double) {
    ctx.setFillColor(black)
    switch ear {
    case .pointy:
        for dx in [-r * 0.5, r * 0.5] {
            ctx.move(to: CGPoint(x: cx + dx, y: cy))
            ctx.addLine(to: CGPoint(x: cx + dx - r * 0.3, y: cy + r * 0.9))
            ctx.addLine(to: CGPoint(x: cx + dx + r * 0.4, y: cy + r * 0.2))
            ctx.closePath(); ctx.fillPath()
        }
    case .floppy:
        ctx.fillEllipse(in: CGRect(x: cx - r * 0.9, y: cy - r * 0.4, width: r * 0.6, height: r * 1.1))
    case .longUp:
        for dx in [-r * 0.35, r * 0.35] {
            ctx.fillEllipse(in: CGRect(x: cx + dx - r * 0.22, y: cy, width: r * 0.44, height: r * 1.8))
        }
    }
}

func drawTail(_ ctx: CGContext, _ tail: Tail, _ x: Double, _ y: Double, _ lineW: Double, _ cycle: Double) {
    ctx.setStrokeColor(black); ctx.setFillColor(black)
    let wag = sin(cycle) * 1.5
    switch tail {
    case .longCurved:
        ctx.setLineWidth(lineW)
        ctx.move(to: CGPoint(x: x, y: y))
        ctx.addQuadCurve(to: CGPoint(x: x - 5, y: y + 6 + wag), control: CGPoint(x: x - 6, y: y))
        ctx.strokePath()
    case .shortUp:
        ctx.setLineWidth(lineW)
        ctx.move(to: CGPoint(x: x, y: y))
        ctx.addLine(to: CGPoint(x: x - 3, y: y + 5 + wag))
        ctx.strokePath()
    case .puff:
        ctx.fillEllipse(in: CGRect(x: x - 3, y: y - 2, width: 3.5, height: 3.5))
    case .flowing:
        ctx.setLineWidth(lineW * 1.4)
        ctx.move(to: CGPoint(x: x, y: y + 2))
        ctx.addQuadCurve(to: CGPoint(x: x - 6, y: y - 3 + wag), control: CGPoint(x: x - 7, y: y + 4))
        ctx.strokePath()
    }
}

// MARK: - Export

func writePNG(_ image: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png encode failed") }
    try! data.write(to: url)
}

let fm = FileManager.default
let assets = URL(fileURLWithPath: "Sources/Zoomies/Assets.xcassets")
try? fm.createDirectory(at: assets, withIntermediateDirectories: true)
try! #"{"info":{"author":"xcode","version":1}}"#
    .write(to: assets.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

for cfg in animals {
    for f in 0..<frameCount {
        let name = "\(cfg.id)_\(f)"
        let dir = assets.appendingPathComponent("\(name).imageset")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        writePNG(render(cfg, frame: f, scale: 1), to: dir.appendingPathComponent("\(name)_1x.png"))
        writePNG(render(cfg, frame: f, scale: 2), to: dir.appendingPathComponent("\(name)_2x.png"))
        let contents = """
        {"images":[{"idiom":"mac","scale":"1x","filename":"\(name)_1x.png"},\
        {"idiom":"mac","scale":"2x","filename":"\(name)_2x.png"}],\
        "info":{"author":"xcode","version":1},\
        "properties":{"template-rendering-intent":"template"}}
        """
        try! contents.write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    }
}
print("Generated \(animals.count) animals × \(frameCount) frames into \(assets.path)")
