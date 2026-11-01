import BarModCore
import CoreGraphics
import Testing

@Test func emptyListKeepsOneRowForItsMessage() {
    #expect(TrayList.visibleRows(for: 0) == 1)
}

@Test func listGrowsWithItems() {
    #expect(TrayList.visibleRows(for: 5) == 5)
    #expect(TrayList.size(for: 5) == CGSize(width: 260, height: 166))
}

@Test func longListStopsGrowingAndScrolls() {
    #expect(TrayList.visibleRows(for: 40) == 12)
    #expect(TrayList.size(for: 40) == TrayList.size(for: 12))
}
