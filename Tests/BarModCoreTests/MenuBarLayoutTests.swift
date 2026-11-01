import BarModCore
import CoreGraphics
import Testing

private let layout = MenuBarLayout(screenX: 0...1512, notchX: 665...850, appMenusMaxX: 400)

private func item(x: CGFloat, width: CGFloat = 30) -> CGRect {
    CGRect(x: x, y: 0, width: width, height: 24)
}

@Test func itemRightOfNotchIsVisible() {
    #expect(!layout.hides(item(x: 900)))
}

@Test func itemTouchingNotchEdgeIsVisible() {
    #expect(!layout.hides(item(x: 850)))
    #expect(!layout.hides(item(x: 635)))
}

@Test func itemOverlappingNotchIsHidden() {
    #expect(layout.hides(item(x: 700)))
    #expect(layout.hides(item(x: 650)))
    #expect(layout.hides(item(x: 840)))
}

// Frames measured on a 14-inch MacBook Pro running macOS 26.
@Test func measuredItemsUnderNotchAreHidden() {
    #expect(layout.hides(item(x: 784, width: 32)))
    #expect(layout.hides(item(x: 816, width: 32)))
}

@Test func paddingOverlappingNotchLeavesItemVisible() {
    #expect(!layout.hides(item(x: 848, width: 32)))
    #expect(!layout.hides(item(x: 640)))
}

@Test func clockOverhangingScreenEdgeIsVisible() {
    #expect(!layout.hides(item(x: 1382, width: 132)))
}

@Test func itemLeftOfNotchClearOfMenusIsVisible() {
    #expect(!layout.hides(item(x: 500)))
}

@Test func itemCoveredByAppMenusIsHidden() {
    #expect(layout.hides(item(x: 300)))
}

@Test func menusPastNotchHideItemsBelowTheirEdge() {
    let wide = MenuBarLayout(screenX: 0...1512, notchX: 665...850, appMenusMaxX: 1000)
    #expect(wide.hides(item(x: 950)))
    #expect(!wide.hides(item(x: 1000)))
}

@Test func itemOffScreenIsHidden() {
    #expect(layout.hides(item(x: -500)))
    #expect(layout.hides(item(x: 1600)))
}

@Test func noNotchLeavesOnlyMenusAndEdges() {
    let flat = MenuBarLayout(screenX: 0...1512, notchX: nil, appMenusMaxX: 400)
    #expect(!flat.hides(item(x: 700)))
    #expect(flat.hides(item(x: 300)))
}
