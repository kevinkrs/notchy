import CoreGraphics

/// Which of the three menu bar sections an item lives in. Defined purely by x-position
/// relative to Notchy's two spacer status items.
enum Section: Equatable {
    case visible, hidden, alwaysHidden
}

/// What the user currently sees.
enum BarState: Equatable {
    /// Only the visible section (default).
    case collapsed
    /// Visible + hidden.
    case expanded
    /// Everything, including always-hidden.
    case all
}

/// Pure geometry. No AppKit.
enum Layout {
    /// Spacer width when it is not pushing anything away.
    static let spacerLength: CGFloat = 8
    /// Spacer width that shoves everything left of it off screen (Hidden Bar / Ice trick).
    static let pushLength: CGFloat = 10000

    static func spacerLengths(for state: BarState) -> (hidden: CGFloat, alwaysHidden: CGFloat) {
        switch state {
        case .collapsed: return (pushLength, spacerLength)
        case .expanded: return (spacerLength, pushLength)
        case .all: return (spacerLength, spacerLength)
        }
    }

    /// Order is preserved when a spacer pushes items off screen, so comparing minX works in every state.
    static func section(itemMinX: CGFloat, hiddenSpacerMinX: CGFloat, alwaysHiddenSpacerMinX: CGFloat) -> Section {
        if itemMinX < alwaysHiddenSpacerMinX { return .alwaysHidden }
        if itemMinX < hiddenSpacerMinX { return .hidden }
        return .visible
    }

    /// Gap kept between the frontmost app's last menu title and the bar, and between the bar and the notch.
    static let notchGap: CGFloat = 12

    /// Origin x of a `width`-wide bar drawn inside the menu bar left of the notch (`area` =
    /// `NSScreen.auxiliaryTopLeftArea`), right-aligned to the notch and clear of the app menus
    /// (which end at `appMenuMaxX`). `nil` when it would not fit.
    static func leftOfNotchX(area: CGRect, appMenuMaxX: CGFloat, width: CGFloat) -> CGFloat? {
        let x = area.maxX - notchGap - width
        return x >= appMenuMaxX + notchGap ? x : nil
    }
}
