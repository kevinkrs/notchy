import AppKit

/// Owns Notchy's three status items. Right to left: toggle (chevron) | hidden spacer | always-hidden spacer.
/// Sections are defined by where other apps' items sit relative to the spacers (user ⌘-drags them).
@MainActor
final class StatusBarController: NSObject {
    private(set) var state: BarState = .collapsed

    /// Left click on the toggle. `showAll` is true when ⌥ was held. The delegate decides what
    /// to do (expand in place vs. open the overflow bar) and calls `setState`.
    var onToggle: ((_ showAll: Bool) -> Void)?
    /// Right-click menu item "Always Use Bar". Persisted in UserDefaults.
    var alwaysUseBar: Bool {
        get { UserDefaults.standard.bool(forKey: "alwaysUseBar") }
        set { UserDefaults.standard.set(newValue, forKey: "alwaysUseBar") }
    }

    /// Screen frames (AppKit coords) of own items. Only minX is compared with other items.
    var toggleFrame: CGRect? { toggle.button?.window?.frame }
    var hiddenSpacerFrame: CGRect? { hiddenSpacer.button?.window?.frame }
    var alwaysHiddenSpacerFrame: CGRect? { alwaysHiddenSpacer.button?.window?.frame }

    private static let names = (toggle: "notchy.toggle", hidden: "notchy.hidden", alwaysHidden: "notchy.alwaysHidden")
    private var toggle: NSStatusItem
    private var hiddenSpacer: NSStatusItem
    private var alwaysHiddenSpacer: NSStatusItem

    override init() {
        if UserDefaults.standard.object(forKey: "NSStatusItem Preferred Position \(Self.names.toggle)") == nil {
            Self.seedPositions()
        }
        (toggle, hiddenSpacer, alwaysHiddenSpacer) = Self.makeItems()
        super.init()
        // Frames are placeholders until AppKit lays the items out; log the real order for diagnostics.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            Diagnostics.log("statusbar", "order valid: \(self.orderIsValid) toggle=\(self.toggleFrame?.minX ?? -1) hidden=\(self.hiddenSpacerFrame?.minX ?? -1) always=\(self.alwaysHiddenSpacerFrame?.minX ?? -1)")
        }
        if let button = toggle.button {
            button.target = self
            button.action = #selector(toggleClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        setState(.collapsed)
    }

    /// Applies `Layout.spacerLengths(for:)` and updates the chevron direction.
    func setState(_ state: BarState) {
        self.state = state
        let lengths = Layout.spacerLengths(for: state)
        hiddenSpacer.length = lengths.hidden
        alwaysHiddenSpacer.length = lengths.alwaysHidden
        toggle.button?.image = NSImage(systemSymbolName: state == .collapsed ? "chevron.left" : "chevron.right",
                                       accessibilityDescription: "Notchy")
    }

    // MARK: - Items

    /// Preferred position = offset from the right edge; larger = further left.
    private static func seedPositions() {
        let defaults = UserDefaults.standard
        for (name, position) in [(names.toggle, 1000.0), (names.hidden, 1010.0), (names.alwaysHidden, 1020.0)] {
            defaults.set(position, forKey: "NSStatusItem Preferred Position \(name)")
            defaults.set(true, forKey: "NSStatusItem Visible \(name)")
        }
    }

    private static func makeItems() -> (NSStatusItem, NSStatusItem, NSStatusItem) {
        let bar = NSStatusBar.system
        let toggle = bar.statusItem(withLength: NSStatusItem.variableLength)
        toggle.autosaveName = names.toggle
        let hidden = bar.statusItem(withLength: Layout.pushLength)
        hidden.autosaveName = names.hidden
        let alwaysHidden = bar.statusItem(withLength: Layout.spacerLength)
        alwaysHidden.autosaveName = names.alwaysHidden
        // macOS 26: an item without content gets a 0×0 window and pushes nothing. Any image fixes it.
        for spacer in [hidden, alwaysHidden] { spacer.button?.image = NSImage(size: NSSize(width: 1, height: 1)) }
        return (toggle, hidden, alwaysHidden)
    }

    /// True when toggle is right of hidden spacer, which is right of always-hidden spacer (or frames unknown yet).
    private var orderIsValid: Bool {
        guard let t = toggleFrame?.minX, let h = hiddenSpacerFrame?.minX, let a = alwaysHiddenSpacerFrame?.minX else { return true }
        return a < h && h < t
    }

    // MARK: - Actions

    @objc private func toggleClicked() {
        guard let button = toggle.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            toggle.menu = buildMenu()
            button.performClick(nil)
            toggle.menu = nil
        } else {
            onToggle?(NSEvent.modifierFlags.contains(.option))
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: state == .collapsed ? "Show Hidden Items" : "Hide Hidden Items",
                     action: #selector(toggleHidden), keyEquivalent: "")
        menu.addItem(withTitle: "Show All Items", action: #selector(showAll), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Always Use Bar", action: #selector(toggleAlwaysUseBar), keyEquivalent: "")
            .state = alwaysUseBar ? .on : .off
        menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
            .state = LoginItem.isEnabled ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Notchy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
        return menu
    }

    @objc private func toggleHidden() { onToggle?(false) }
    @objc private func showAll() { onToggle?(true) }
    @objc private func toggleAlwaysUseBar() { alwaysUseBar.toggle() }
    @objc private func toggleLoginItem() { LoginItem.set(!LoginItem.isEnabled) }
}
