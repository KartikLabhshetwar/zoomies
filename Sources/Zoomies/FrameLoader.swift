import AppKit
import ZoomiesCore

enum FrameLoader {
    /// Height the menu bar icon is scaled to (points).
    static let iconHeight: CGFloat = 18

    static func load(_ animal: Animal) -> [NSImage] {
        animal.frameNames.compactMap { name in
            guard let original = NSImage(named: name) else {
                NSLog("Zoomies: missing frame \(name)")
                return nil
            }
            // Copy so we don't mutate the shared cached asset-catalog image.
            guard let image = original.copy() as? NSImage else { return nil }
            // oneko is rendered in its real colors — not as a monochrome template.
            image.isTemplate = false
            let aspect = image.size.height > 0 ? image.size.width / image.size.height : 1
            image.size = NSSize(width: iconHeight * aspect, height: iconHeight)
            return image
        }
    }

    /// Horizontally-mirrored copies of the given frames — used to make the cat face
    /// right (oneko's sprites are drawn facing left).
    static func mirrored(_ images: [NSImage]) -> [NSImage] {
        images.map { image in
            let size = image.size
            let flipped = NSImage(size: size, flipped: false) { rect in
                guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
                ctx.translateBy(x: size.width, y: 0)
                ctx.scaleBy(x: -1, y: 1)
                image.draw(in: rect)
                return true
            }
            flipped.isTemplate = image.isTemplate
            return flipped
        }
    }
}
