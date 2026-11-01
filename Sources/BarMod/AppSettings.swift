import BarModCore
import Foundation
import Observation
import ServiceManagement

/// User choices, saved in UserDefaults.
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let style = "popupStyle"
        static let showsLogos = "showsAppLogos"
    }

    var style: TrayStyle {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: Key.style) }
    }

    /// Only the list can hide logos: a grid cell has nothing else to show.
    var showsLogos: Bool {
        didSet { UserDefaults.standard.set(showsLogos, forKey: Key.showsLogos) }
    }

    init() {
        let defaults = UserDefaults.standard
        style = defaults.string(forKey: Key.style).flatMap(TrayStyle.init(rawValue:)) ?? .grid
        showsLogos = defaults.object(forKey: Key.showsLogos) == nil || defaults.bool(forKey: Key.showsLogos)
    }
}

/// "Start at Login", read from the system so it stays correct if the user
/// changes it in System Settings.
@MainActor
@Observable
final class LoginItem {
    private(set) var isEnabled = false
    private(set) var errorMessage: String?

    /// A copy run from a build folder must never become the login item.
    var canRegister: Bool { Bundle.main.bundlePath.contains("/Applications/") }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        let service = SMAppService.mainApp
        errorMessage = nil
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
            Log.write("login item failed: \(error)")
        }
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        refresh()
    }
}
