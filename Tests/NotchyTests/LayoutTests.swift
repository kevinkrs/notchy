import CoreGraphics
import Testing
@testable import Notchy

// Command Line Tools ship Swift Testing but not XCTest.

@Suite("Layout")
struct LayoutTests {
    @Test func collapsedPushesHiddenOnly() {
        let l = Layout.spacerLengths(for: .collapsed)
        #expect(l.hidden == Layout.pushLength && l.alwaysHidden == Layout.spacerLength)
    }

    @Test func expandedPushesAlwaysHiddenOnly() {
        let l = Layout.spacerLengths(for: .expanded)
        #expect(l.hidden == Layout.spacerLength && l.alwaysHidden == Layout.pushLength)
    }

    @Test func allPushesNothing() {
        let l = Layout.spacerLengths(for: .all)
        #expect(l.hidden == Layout.spacerLength && l.alwaysHidden == Layout.spacerLength)
    }

    @Test func sectionByPosition() {
        // always-hidden spacer at 100, hidden spacer at 200
        #expect(Layout.section(itemMinX: 50, hiddenSpacerMinX: 200, alwaysHiddenSpacerMinX: 100) == .alwaysHidden)
        #expect(Layout.section(itemMinX: 150, hiddenSpacerMinX: 200, alwaysHiddenSpacerMinX: 100) == .hidden)
        #expect(Layout.section(itemMinX: 250, hiddenSpacerMinX: 200, alwaysHiddenSpacerMinX: 100) == .visible)
    }

    @Test func sectionWorksWhilePushedOffScreen() {
        // collapsed: everything left of the hidden spacer is at x < -9000
        #expect(Layout.section(itemMinX: -9950, hiddenSpacerMinX: -9900, alwaysHiddenSpacerMinX: -9980) == .hidden)
        #expect(Layout.section(itemMinX: -9990, hiddenSpacerMinX: -9900, alwaysHiddenSpacerMinX: -9980) == .alwaysHidden)
    }

    @Test func leftOfNotchPlacement() {
        let area = CGRect(x: 0, y: 0, width: 600, height: 37) // left of notch, notch starts at 600
        #expect(Layout.leftOfNotchX(area: area, appMenuMaxX: 300, width: 200) == 388)
        #expect(Layout.leftOfNotchX(area: area, appMenuMaxX: 300, width: 280) == nil) // 600-12-280 = 308 < 312
    }

    @Test @MainActor func moveDestinations() {
        // collapsed: hidden spacer is the 10000 pt pusher ending at the toggle, always-hidden spacer pushed far left
        let d = ItemMover.Dividers(hidden: CGRect(x: -8818, y: 0, width: 10000, height: 24),
                                   alwaysHidden: CGRect(x: -8840, y: 0, width: 8, height: 24))
        #expect(ItemMover.destinationX(for: .visible, dividers: d) == 1186)       // right of the pusher, left of ⌃
        #expect(ItemMover.destinationX(for: .hidden, dividers: d) == -8822)       // just left of the pusher
        #expect(ItemMover.destinationX(for: .alwaysHidden, dividers: d) == -8844) // just left of ⸰
    }
}
