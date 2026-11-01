import CoreGraphics

/// The regions of one screen's menu bar that can hide a status item.
///
/// Accessibility frames use a top-left origin and AppKit a bottom-left one,
/// but x values are identical in both, so only x is compared.
public struct MenuBarLayout: Sendable, Equatable {
    public var screenX: ClosedRange<CGFloat>
    public var notchX: ClosedRange<CGFloat>?
    /// Right edge of the frontmost app's menus; status items cannot draw over them.
    public var appMenusMaxX: CGFloat

    public init(screenX: ClosedRange<CGFloat>, notchX: ClosedRange<CGFloat>?, appMenusMaxX: CGFloat) {
        self.screenX = screenX
        self.notchX = notchX
        self.appMenusMaxX = appMenusMaxX
    }

    /// Status item frames include empty padding around the glyph, so an overlap
    /// up to this size covers nothing the user can see.
    private static let glyphPadding: CGFloat = 8

    public func hides(_ frame: CGRect) -> Bool {
        // The rightmost frame can overhang the screen edge while fully usable.
        if frame.maxX <= screenX.lowerBound || frame.minX >= screenX.upperBound {
            return true
        }
        if let notchX {
            let overlap = min(frame.maxX, notchX.upperBound) - max(frame.minX, notchX.lowerBound)
            if overlap > Self.glyphPadding { return true }
        }
        return frame.minX < appMenusMaxX - Self.glyphPadding
    }
}
