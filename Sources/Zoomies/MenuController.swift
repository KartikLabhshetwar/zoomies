import AppKit
import ZoomiesCore

/// Builds and owns the status-item click menu: live CPU / GPU / RAM readout plus
/// Settings and Quit.
final class MenuController: NSObject {
    private let menu = NSMenu()

    // Three fixed metric rows so they can be updated without rebuilding the menu.
    private let cpuItem  = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let gpuItem  = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let ramItem  = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    private let onOpenSettings: () -> Void

    init(onOpenSettings: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
        super.init()
    }

    func buildMenu() -> NSMenu {
        for item in [cpuItem, gpuItem, ramItem] { item.isEnabled = false }

        // Monospaced font so the bars align cleanly.
        let mono = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        cpuItem.attributedTitle = NSAttributedString(string: "CPU  —%  ░░░░░░░░░░",
                                                     attributes: [.font: mono])
        gpuItem.attributedTitle = NSAttributedString(string: "GPU  —%  ░░░░░░░░░░",
                                                     attributes: [.font: mono])
        ramItem.attributedTitle = NSAttributedString(string: "RAM  —%  ░░░░░░░░░░",
                                                     attributes: [.font: mono])

        menu.addItem(cpuItem)
        menu.addItem(gpuItem)
        menu.addItem(ramItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem(title: "Quit Zoomies",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        return menu
    }

    /// Update all three metric rows at once.
    func setMetrics(cpu: Double, gpu: Double, ram: Double) {
        let mono = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        cpuItem.attributedTitle = metricLine("CPU", value: cpu, font: mono)
        gpuItem.attributedTitle = metricLine("GPU", value: gpu, font: mono)
        ramItem.attributedTitle = metricLine("RAM", value: ram, font: mono)
    }

    // MARK: -

    /// e.g.  "CPU  42%  ●●●●●○○○○○"
    private func metricLine(_ label: String, value: Double, font: NSFont) -> NSAttributedString {
        let pct  = Int((value * 100).rounded())
        let fill = min(10, Int((value * 10).rounded()))
        let bar  = String(repeating: "●", count: fill) + String(repeating: "○", count: 10 - fill)
        let padded = (label + "   ").prefix(4)           // left-pad to 4 chars
        let pctStr = String(format: "%3d%%", pct)
        let text   = "\(padded) \(pctStr)  \(bar)"

        let tint: NSColor
        switch value {
        case ..<0.5:  tint = NSColor.secondaryLabelColor
        case ..<0.75: tint = NSColor.systemOrange
        default:      tint = NSColor.systemRed
        }

        let result = NSMutableAttributedString(string: text,
                                               attributes: [.font: font, .foregroundColor: tint])
        // Label part (first 4 chars) is always normal label color.
        result.addAttribute(.foregroundColor, value: NSColor.labelColor,
                            range: NSRange(location: 0, length: min(4, (text as NSString).length)))
        return result
    }

    @objc private func openSettings() { onOpenSettings() }
}
