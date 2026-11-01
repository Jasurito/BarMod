import AppKit

let arguments = CommandLine.arguments
if let flag = arguments.firstIndex(of: "--dump"), flag + 1 < arguments.count {
    Diagnostics.dump(to: arguments[flag + 1])
    exit(0)
}
if let flag = arguments.firstIndex(of: "--press"), flag + 2 < arguments.count {
    Diagnostics.press(matching: arguments[flag + 1], to: arguments[flag + 2])
    exit(0)
}
if let flag = arguments.firstIndex(of: "--panel"), flag + 1 < arguments.count {
    Diagnostics.panel(to: arguments[flag + 1], pressing: flag + 2 < arguments.count ? arguments[flag + 2] : nil)
    exit(0)
}
if let flag = arguments.firstIndex(of: "--render-preview"), flag + 1 < arguments.count {
    Diagnostics.renderPreview(to: arguments[flag + 1])
    exit(0)
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
