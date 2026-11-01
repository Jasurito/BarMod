import BarModCore
import CoreGraphics
import Testing

@Test func columnsStayWithinBounds() {
    #expect(TrayGrid.columns(for: 0) == 4)
    #expect(TrayGrid.columns(for: 5) == 5)
    #expect(TrayGrid.columns(for: 40) == 6)
}

@Test func rowsRoundUpAndNeverReachZero() {
    #expect(TrayGrid.rows(for: 0) == 1)
    #expect(TrayGrid.rows(for: 6) == 1)
    #expect(TrayGrid.rows(for: 7) == 2)
    #expect(TrayGrid.rows(for: 13) == 3)
}

@Test func panelCentresUnderAnchor() {
    #expect(TrayGrid.originX(anchorMidX: 1000, panelWidth: 200, screenX: 0...1512) == 900)
}

@Test func panelStaysOnScreen() {
    #expect(TrayGrid.originX(anchorMidX: 1500, panelWidth: 200, screenX: 0...1512) == 1304)
    #expect(TrayGrid.originX(anchorMidX: 10, panelWidth: 200, screenX: 0...1512) == 8)
}
