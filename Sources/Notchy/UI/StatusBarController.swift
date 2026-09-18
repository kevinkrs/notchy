import AppKit

/// Owns Notchy's three status items. Right to left: toggle (chevron) | hidden spacer | always-hidden spacer.
/// Sections are defined by where other apps' items sit relative to the spacers (user ⌘-drags them).
@MainActor
final class StatusBarController {
    private(set) var state: BarState = .collapsed

    /// Left click on the toggle. `showAll` is true when ⌥ was held. The delegate decides what
    /// to do (expand in place vs. open the overflow bar) and calls `setState`.
    var onToggle: ((_ showAll: Bool) -> Void)?
    /// Right-click menu item "Always Use Bar". Persisted in UserDefaults.
    var alwaysUseBar: Bool {
        get { fatalError("TODO: agent A") }
        set { fatalError("TODO: agent A") }
    }

    /// Window IDs of the three own status item windows, for `ItemScanner.scan(excluding:)`.
    var ownWindowIDs: Set<CGWindowID> { fatalError("TODO: agent A") }
    /// Screen frames (AppKit coords) of own items. Only minX is compared with other items.
    var toggleFrame: CGRect? { fatalError("TODO: agent A") }
    var hiddenSpacerFrame: CGRect? { fatalError("TODO: agent A") }
    var alwaysHiddenSpacerFrame: CGRect? { fatalError("TODO: agent A") }

    init() { fatalError("TODO: agent A") }

    /// Applies `Layout.spacerLengths(for:)` and updates the chevron direction.
    func setState(_ state: BarState) { fatalError("TODO: agent A") }
}
