import AppKit
import ApplicationServices
import BarModCore
import SwiftUI

/// Support modes that print what BarMod sees. Run the dump through `open` so
/// macOS checks BarMod's own permissions, not the terminal's:
/// `open -n -W build/BarMod.app --args --dump /tmp/barmod-dump.txt`
@MainActor
enum Diagnostics {
    static func dump(to path: String) {
        let trusted = AXIsProcessTrusted()
        var lines = ["trusted=\(trusted) screenRecording=\(CGPreflightScreenCaptureAccess())"]
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
        guard let screen else {
            write(lines + ["no screen"], to: path)
            return
        }
        let geometry = ScreenGeometry(screen: screen)
        lines.append("screen=\(screen.localizedName) frame=\(screen.frame) notch=\(String(describing: geometry.notchX))")
        lines.append("screens=\(NSScreen.screens.count)")

        let front = NSWorkspace.shared.frontmostApplication
        lines.append("frontmost=\(front?.localizedName ?? "?")")
        for (index, frame) in MenuBarScanner.appMenuFrames(pid: front?.processIdentifier).enumerated() {
            lines.append("  menu[\(index)] \(frame)")
        }

        let snapshot = MenuBarScanner.scan(
            apps: RunningApp.snapshot(),
            geometry: geometry,
            frontmostPID: front?.processIdentifier,
            excluding: nil
        )
        lines.append("appMenusMaxX=\(snapshot.layout.appMenusMaxX)")
        lines.append("items=\(snapshot.items.count) hidden=\(snapshot.hidden.count)")
        for item in snapshot.items {
            let state = snapshot.layout.hides(item.frame) ? "HIDDEN " : "visible"
            lines.append("  [\(state)] \(item.frame) \(item.displayName) actions=\(AX.actions(item.element))")
        }

        let onScreen = Set(windowInfo(.optionOnScreenOnly).compactMap { $0[kCGWindowNumber as String] as? Int })
        lines.append("layer25 windows:")
        for window in windowInfo(.optionAll) where window[kCGWindowLayer as String] as? Int == 25 {
            let number = window[kCGWindowNumber as String] as? Int ?? 0
            let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            let owner = window[kCGWindowOwnerName as String] as? String ?? "?"
            let alpha = window[kCGWindowAlpha as String] as? Double ?? -1
            lines.append("  win=\(number) x=\(bounds["X"] ?? -1) y=\(bounds["Y"] ?? -1) w=\(bounds["Width"] ?? -1) h=\(bounds["Height"] ?? -1) onScreen=\(onScreen.contains(number)) alpha=\(alpha) owner=\(owner)")
        }
        write(lines, to: path)
    }

    /// Presses the first item whose name contains `name` and reports which
    /// windows appeared, which shows where its menu opened.
    static func press(matching name: String, to path: String) {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        let snapshot = MenuBarScanner.scan(
            apps: RunningApp.snapshot(),
            geometry: ScreenGeometry(screen: screen),
            frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
            excluding: nil
        )
        guard let item = snapshot.items.first(where: { $0.displayName.localizedCaseInsensitiveContains(name) }) else {
            write(["no item matching \(name)"], to: path)
            return
        }
        let before = Set(windowInfo(.optionAll).compactMap { $0[kCGWindowNumber as String] as? Int })
        let result = MenuBarScanner.press(item)
        Thread.sleep(forTimeInterval: 0.8)

        var lines = ["pressed \(item.displayName) frame=\(item.frame) result=\(result.rawValue)"]
        for window in windowInfo(.optionAll) {
            let number = window[kCGWindowNumber as String] as? Int ?? 0
            guard !before.contains(number) else { continue }
            let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            let owner = window[kCGWindowOwnerName as String] as? String ?? "?"
            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            lines.append("  new win=\(number) x=\(bounds["X"] ?? -1) y=\(bounds["Y"] ?? -1) w=\(bounds["Width"] ?? -1) h=\(bounds["Height"] ?? -1) layer=\(layer) owner=\(owner)")
        }
        write(lines, to: path)
    }

    /// Lists the buttons in the running BarMod's popup through Accessibility,
    /// and presses the one containing `label` when given. This takes the same
    /// path as a user's click.
    static func panel(to path: String, pressing label: String?) {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.jasurito.BarMod")
        guard let pid = running.map(\.processIdentifier).first(where: { $0 != ownPID }) else {
            write(["BarMod is not running"], to: path)
            return
        }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 1)
        let windows = AX.attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
        var lines = windows.map { "window frame=\(AX.frame($0).map(String.init(describing:)) ?? "?")" }
        let buttons = windows.flatMap { descendantButtons(of: $0, depth: 0) }
        lines += buttons.map { "button \(AX.string($0, kAXDescriptionAttribute) ?? "?")" }
        if let label, let button = buttons.first(where: {
            AX.string($0, kAXDescriptionAttribute)?.localizedCaseInsensitiveContains(label) == true
        }) {
            let result = AXUIElementPerformAction(button, kAXPressAction as CFString)
            lines.append("pressed \(label) result=\(result.rawValue)")
        }
        write(lines, to: path)
    }

    private static func descendantButtons(of element: AXUIElement, depth: Int) -> [AXUIElement] {
        guard depth < 12 else { return [] }
        let own = AX.string(element, kAXRoleAttribute) == kAXButtonRole ? [element] : []
        return own + AX.children(element).flatMap { descendantButtons(of: $0, depth: depth + 1) }
    }

    /// Renders every menu bar icon in the popup layout, for checking icons
    /// without a screen. Needs Accessibility, so run it through `open`.
    static func renderPreview(to path: String) {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        let snapshot = MenuBarScanner.scan(
            apps: RunningApp.snapshot(),
            geometry: ScreenGeometry(screen: screen),
            frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
            excluding: nil
        )
        let model = TrayModel()
        model.isTrusted = true
        model.hiddenItems = snapshot.items
        renderPopup(model, to: path)
    }

    private static func renderPopup(_ model: TrayModel, to path: String) {
        let view = TrayView(model: model, onPress: { _ in }, onOpenAccessibilitySettings: {})
            .environment(\.colorScheme, .dark)
            .padding(12)
            .background(Color.black)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage else {
            print("render failed")
            return
        }
        writePNG(image, to: path)
    }

    private static func writePNG(_ image: CGImage, to path: String) {
        let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        FileManager.default.createFile(atPath: path, contents: data)
    }

    private static func windowInfo(_ option: CGWindowListOption) -> [[String: Any]] {
        CGWindowListCopyWindowInfo(option, kCGNullWindowID) as? [[String: Any]] ?? []
    }

    private static func write(_ lines: [String], to path: String) {
        FileManager.default.createFile(atPath: path, contents: lines.joined(separator: "\n").appending("\n").data(using: .utf8))
    }
}
