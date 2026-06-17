import AppKit
import ZoomiesCore

enum FrameLoader {
    /// Height the menu bar icon is scaled to (points).
    static let iconHeight: CGFloat = 18

    static func load(_ animal: Animal) -> [NSImage] {
        animal.frameNames.compactMap { name in
            guard let image = NSImage(named: name) else {
                NSLog("Zoomies: missing frame \(name)")
                return nil
            }
            image.isTemplate = true
            let aspect = image.size.height > 0 ? image.size.width / image.size.height : 1
            image.size = NSSize(width: iconHeight * aspect, height: iconHeight)
            return image
        }
    }
}
