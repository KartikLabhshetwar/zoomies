import AppKit
import ZoomiesCore

/// Watches horizontal cursor movement anywhere on screen and reports when the cat
/// should turn to face a new direction.
///
/// Uses a global event monitor for `.mouseMoved`. Mouse events (unlike keyboard
/// events) don't require Accessibility permission, so this works out of the box for
/// a menu-bar-only app. Handlers fire on the main thread, so it's safe to drive UI.
final class MouseDirectionMonitor {
    var onChange: ((DirectionTracker.Direction) -> Void)?

    private var monitor: Any?
    private var tracker = DirectionTracker()

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            guard let self else { return }
            if let direction = self.tracker.update(x: Double(NSEvent.mouseLocation.x)) {
                self.onChange?(direction)
            }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    deinit { stop() }
}
