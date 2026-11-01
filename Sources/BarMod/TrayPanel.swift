import AppKit
import BarModCore
import SwiftUI

/// Non-activating panels are often not key, and a plain hosting view would
/// swallow the first click.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Popup under BarMod's icon. Non-activating, so the frontmost app keeps its
/// menus and the scan sees the layout the user is looking at.
@MainActor
final class TrayPanel: NSPanel {
    private static let escapeKeyCode: UInt16 = 53

    private let model: TrayModel
    private var outsideClickMonitor: Any?
    private var keyMonitor: Any?
    private weak var anchor: NSStatusBarButton?

    init(model: TrayModel, onPress: @escaping (TrayItem) -> Void, onOpenAccessibilitySettings: @escaping () -> Void) {
        self.model = model
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let hosting = FirstClickHostingView(rootView: TrayView(
            model: model,
            onPress: onPress,
            onOpenAccessibilitySettings: onOpenAccessibilitySettings
        ))
        hosting.sizingOptions = []
        contentView = hosting
    }

    override var canBecomeKey: Bool { true }

    func show(below button: NSStatusBarButton) {
        anchor = button
        appearance = button.effectiveAppearance
        fitToContent()
        makeKeyAndOrderFront(nil)
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == TrayPanel.escapeKeyCode else { return event }
            self?.hide()
            return nil
        }
    }

    func hide() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        outsideClickMonitor = nil
        keyMonitor = nil
        orderOut(nil)
    }

    /// Sizes from the model, because SwiftUI has not laid out new state yet.
    func fitToContent() {
        guard let buttonWindow = anchor?.window, let screen = buttonWindow.screen ?? NSScreen.main else { return }
        let size = model.panelSize
        let originX = TrayGrid.originX(
            anchorMidX: buttonWindow.frame.midX,
            panelWidth: size.width,
            screenX: screen.frame.minX...screen.frame.maxX
        )
        let top = buttonWindow.frame.minY - TrayGrid.gapBelowMenuBar
        setFrame(NSRect(x: originX, y: top - size.height, width: size.width, height: size.height), display: true)
        invalidateShadow()
    }
}
