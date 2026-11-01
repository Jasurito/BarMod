import AppKit
import BarModCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let autosaveName = "BarModMain"
    /// New items land nearest the notch, the first spot macOS drops. This is
    /// AppKit's stored distance from the right edge, so seeding it keeps
    /// BarMod's own icon visible. A later ⌘-drag overwrites it.
    private static let seededPosition = 300
    private static let accessibilitySettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    private let settings = AppSettings()
    private lazy var model = TrayModel(settings: settings)
    private lazy var settingsWindow = SettingsWindow(settings: settings)
    private var statusItem: NSStatusItem?
    private var panel: TrayPanel?
    private var refreshTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = TrayPanel(
            model: model,
            onPress: { [weak self] item in self?.press(item) },
            onOpenAccessibilitySettings: { [weak self] in self?.openAccessibilitySettings() }
        )
        createStatusItem()
        if !AXIsProcessTrusted() { AX.requestTrust() }
    }

    private func createStatusItem() {
        let positionKey = "NSStatusItem Preferred Position \(Self.autosaveName)"
        if UserDefaults.standard.object(forKey: positionKey) == nil {
            UserDefaults.standard.set(Self.seededPosition, forKey: positionKey)
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = Self.autosaveName
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "BarMod")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    private func togglePanel() {
        guard let panel, let button = statusItem?.button else { return }
        if panel.isVisible {
            panel.hide()
            return
        }
        model.isTrusted = AXIsProcessTrusted()
        panel.show(below: button)
        guard model.isTrusted else { return }
        refresh(screen: button.window?.screen)
    }

    private func refresh(screen: NSScreen?) {
        guard let screen = screen ?? NSScreen.main else { return }
        let geometry = ScreenGeometry(screen: screen)
        let apps = RunningApp.snapshot()
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let ownPID = ProcessInfo.processInfo.processIdentifier
        model.isLoading = true
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            let snapshot = await Task.detached(priority: .userInitiated) {
                MenuBarScanner.scan(apps: apps, geometry: geometry, frontmostPID: frontmostPID, excluding: ownPID)
            }.value
            guard let self, !Task.isCancelled else { return }
            self.model.hiddenItems = snapshot.hidden
            self.model.isLoading = false
            self.panel?.fitToContent()
        }
    }

    private func press(_ item: TrayItem) {
        panel?.hide()
        Task.detached(priority: .userInitiated) {
            // Lets the panel leave the screen before the item's menu takes over.
            try? await Task.sleep(for: .milliseconds(80))
            MenuBarScanner.press(item)
        }
    }

    private func openAccessibilitySettings() {
        panel?.hide()
        NSWorkspace.shared.open(Self.accessibilitySettingsURL)
    }

    private func showContextMenu() {
        guard let statusItem, let button = statusItem.button else { return }
        panel?.hide()
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit BarMod", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }
}
