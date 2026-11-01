import CoreGraphics

/// Popup geometry. Kept separate from the view so the panel can be sized
/// before SwiftUI has laid anything out.
public enum TrayGrid {
    public static let cell = CGSize(width: 40, height: 36)
    public static let padding: CGFloat = 8
    public static let footerHeight: CGFloat = 22
    public static let minColumns = 4
    public static let maxColumns = 6
    public static let gapBelowMenuBar: CGFloat = 6
    public static let screenMargin: CGFloat = 8

    public static func columns(for count: Int) -> Int {
        min(max(count, minColumns), maxColumns)
    }

    public static func rows(for count: Int) -> Int {
        max(1, Int((Double(count) / Double(columns(for: count))).rounded(.up)))
    }

    public static func size(for count: Int) -> CGSize {
        CGSize(
            width: CGFloat(columns(for: count)) * cell.width + padding * 2,
            height: CGFloat(rows(for: count)) * cell.height + footerHeight + padding * 2
        )
    }

    /// Centres the panel under its anchor without crossing a screen edge.
    public static func originX(anchorMidX: CGFloat, panelWidth: CGFloat, screenX: ClosedRange<CGFloat>) -> CGFloat {
        let lowest = screenX.lowerBound + screenMargin
        let highest = screenX.upperBound - screenMargin - panelWidth
        return max(lowest, min(anchorMidX - panelWidth / 2, highest))
    }
}
