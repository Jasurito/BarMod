import AppKit
import ApplicationServices
import BarModCore

struct RunningApp: Sendable {
    let pid: pid_t
    let name: String
    let bundleID: String?

    @MainActor
    static func snapshot() -> [RunningApp] {
        NSWorkspace.shared.runningApplications.map {
            RunningApp(
                pid: $0.processIdentifier,
                name: $0.localizedName ?? $0.bundleIdentifier ?? "Unknown",
                bundleID: $0.bundleIdentifier
            )
        }
    }
}

/// One app's status item. `AXUIElement` is safe to use across threads.
struct TrayItem: Identifiable, @unchecked Sendable {
    let id: String
    let pid: pid_t
    let appName: String
    let bundleID: String?
    let detail: String
    let frame: CGRect
    let element: AXUIElement

    var displayName: String {
        detail.isEmpty || detail == appName ? appName : "\(appName): \(detail)"
    }

    /// Control Center items need a symbol. Other apps use their app icon.
    var systemSymbol: String? {
        bundleID == "com.apple.controlcenter" ? SystemIcon.symbolName(forDescription: detail) : nil
    }
}

struct ScreenGeometry: Sendable {
    let screenX: ClosedRange<CGFloat>
    let notchX: ClosedRange<CGFloat>?

    @MainActor
    init(screen: NSScreen) {
        screenX = screen.frame.minX...screen.frame.maxX
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea, left.maxX <= right.minX {
            notchX = left.maxX...right.minX
        } else {
            notchX = nil
        }
    }
}

struct MenuBarSnapshot: Sendable {
    let layout: MenuBarLayout
    let items: [TrayItem]

    var hidden: [TrayItem] { items.filter { layout.hides($0.frame) } }
}

private final class ItemCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [TrayItem] = []

    func add(_ new: [TrayItem]) {
        lock.lock()
        defer { lock.unlock() }
        items.append(contentsOf: new)
    }

    func drain() -> [TrayItem] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }
}

/// Finds status items through each app's `AXExtrasMenuBar`.
///
/// On macOS 26 Control Center owns the status item windows, so window owners
/// no longer say which app an icon belongs to. The AX tree is still per app.
/// Blocks on slow apps, so never call from the main thread.
enum MenuBarScanner {
    private static let messagingTimeout: Float = 0.25
    private static let maxItemWidth: CGFloat = 400
    /// Apps can keep empty placeholder items only a couple of points wide.
    private static let minItemWidth: CGFloat = 8

    static func scan(apps: [RunningApp], geometry: ScreenGeometry, frontmostPID: pid_t?, excluding excludedPID: pid_t?) -> MenuBarSnapshot {
        let collector = ItemCollector()
        DispatchQueue.concurrentPerform(iterations: apps.count) { index in
            let app = apps[index]
            guard app.pid != excludedPID else { return }
            collector.add(items(of: app))
        }
        let layout = MenuBarLayout(
            screenX: geometry.screenX,
            notchX: geometry.notchX,
            appMenusMaxX: appMenusMaxX(pid: frontmostPID, screenX: geometry.screenX)
        )
        return MenuBarSnapshot(layout: layout, items: collector.drain().sorted { $0.frame.minX < $1.frame.minX })
    }

    private static func items(of app: RunningApp) -> [TrayItem] {
        let appElement = AXUIElementCreateApplication(app.pid)
        AXUIElementSetMessagingTimeout(appElement, messagingTimeout)
        guard let extras = AX.element(appElement, "AXExtrasMenuBar") else { return [] }
        return AX.children(extras).compactMap { child in
            guard let frame = AX.frame(child), frame.width >= minItemWidth, frame.width < maxItemWidth else { return nil }
            return TrayItem(
                id: "\(app.pid)-\(CFHash(child))",
                pid: app.pid,
                appName: app.name,
                bundleID: app.bundleID,
                detail: AX.string(child, kAXDescriptionAttribute) ?? AX.string(child, kAXTitleAttribute) ?? "",
                frame: frame,
                element: child
            )
        }
    }

    static func appMenuFrames(pid: pid_t?) -> [CGRect] {
        guard let pid else { return [] }
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, messagingTimeout)
        guard let menuBar = AX.element(appElement, kAXMenuBarAttribute) else { return [] }
        return AX.children(menuBar).compactMap(AX.frame)
    }

    private static func appMenusMaxX(pid: pid_t?, screenX: ClosedRange<CGFloat>) -> CGFloat {
        appMenuFrames(pid: pid)
            .filter { $0.width > 0 && screenX.contains($0.minX) }
            .map(\.maxX)
            .max() ?? screenX.lowerBound
    }

    /// Opens the item's own menu. An app stuck in menu tracking may not answer
    /// until the menu closes, so a timeout does not mean the press failed.
    @discardableResult
    static func press(_ item: TrayItem) -> AXError {
        AXUIElementSetMessagingTimeout(item.element, 0.5)
        let result = AXUIElementPerformAction(item.element, kAXPressAction as CFString)
        Log.write("press \(item.displayName) frame=\(item.frame) result=\(result.rawValue)")
        return result
    }
}
