import AppKit
import BarModCore
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let loginItem: LoginItem

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        Form {
            Section {
                Picker("Layout", selection: $settings.style) {
                    Text("Grid").tag(TrayStyle.grid)
                    Text("List").tag(TrayStyle.list)
                }
                .pickerStyle(.segmented)

                Toggle("Show app logos", isOn: $settings.showsLogos)
                    .disabled(settings.style == .grid)
            } header: {
                Text("Popup")
            } footer: {
                if settings.style == .grid {
                    Text("Grid always shows logos.").font(.caption).foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Start at login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                .disabled(!loginItem.canRegister)
            } header: {
                Text("General")
            } footer: {
                VStack(alignment: .leading, spacing: 2) {
                    if !loginItem.canRegister {
                        Text("Available when BarMod runs from Applications.")
                    }
                    if let message = loginItem.errorMessage {
                        Text(message)
                    }
                    Text("BarMod \(version)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// BarMod has no Dock icon or main menu, so this owns its one regular window.
@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
    private let settings: AppSettings
    private let loginItem = LoginItem()
    private var window: NSWindow?
    private var previousApp: NSRunningApplication?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func show() {
        loginItem.refresh()
        let window = window ?? makeWindow()
        self.window = window
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost != NSRunningApplication.current { previousApp = frontmost }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    /// macOS leaves a windowless accessory app frontmost, which would take
    /// keyboard focus from the app the user came from.
    func windowWillClose(_ notification: Notification) {
        if NSApp.isActive { previousApp?.activate() }
        previousApp = nil
    }

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsView(settings: settings, loginItem: loginItem))
        hosting.sizingOptions = .preferredContentSize
        let window = NSWindow(contentViewController: hosting)
        window.title = "BarMod Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }
}
