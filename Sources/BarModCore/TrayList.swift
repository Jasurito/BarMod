import CoreGraphics

/// How the popup arranges hidden icons.
public enum TrayStyle: String, CaseIterable, Sendable {
    case grid
    case list
}

/// Geometry of the list style. Longer lists scroll.
public enum TrayList {
    public static let width: CGFloat = 260
    public static let rowHeight: CGFloat = 30
    public static let maxVisibleRows = 12

    public static func visibleRows(for count: Int) -> Int {
        min(max(count, 1), maxVisibleRows)
    }

    public static func size(for count: Int) -> CGSize {
        CGSize(
            width: width,
            height: CGFloat(visibleRows(for: count)) * rowHeight + TrayGrid.padding * 2
        )
    }
}
