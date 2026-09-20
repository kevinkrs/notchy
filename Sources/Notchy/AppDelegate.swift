import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController!
    private let panel = OverflowPanel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController()
        statusBar.setState(.collapsed)
        statusBar.onToggle = { [weak self] showAll in self?.toggle(showAll: showAll) }
        statusBar.onShowAll = { [weak self] in self?.showAllInPanel() }
        panel.onSelect = { [weak self] item in self?.forward(item) }
        panel.onDismiss = { [weak self] in
            // Panel closed without a click: nothing was revealed, stay collapsed.
            if self?.statusBar.state == .collapsed { self?.statusBar.setState(.collapsed) }
        }
        Diagnostics.log("app", "launched")
    }

    // MARK: - Toggle decision

    /// Click: expand in place so macOS shows as many items as fit right of the notch; whatever it drops
    /// behind the notch lands in the bar left of the notch (`showDroppedItems`). ⌥-click: same with the
    /// always-hidden section too (arrange mode, both dividers visible). "Always Use Bar": hidden items go
    /// straight to the bar, nothing moves.
    private func toggle(showAll: Bool) {
        if panel.isVisible { panel.hide() }
        if statusBar.state != .collapsed && !showAll {
            statusBar.setState(.collapsed)
            return
        }
        let target: BarState = showAll ? .all : .expanded
        Diagnostics.log("app", "toggle showAll=\(showAll) state=\(statusBar.state) toggle=\(Int(statusBar.toggleFrame?.minX ?? -1)) hidden=\(Int(statusBar.hiddenSpacerFrame?.minX ?? -1)) always=\(Int(statusBar.alwaysHiddenSpacerFrame?.minX ?? -1))")
        if statusBar.alwaysUseBar, !showAll {
            let hidden = scan().filter { section(of: $0) == .hidden }
            if !hidden.isEmpty { return showPanel(hidden, below: false) }
        }
        statusBar.setState(target)
        showDroppedItems(after: target)
    }

    /// Right-click → "Show All Items": every hidden and always-hidden item in the panel below the toggle,
    /// menu bar untouched.
    private func showAllInPanel() {
        if panel.isVisible { return panel.hide() }
        let items = scan().filter { section(of: $0) != .visible }
        if items.isEmpty { return statusBar.setState(.all) } // no permission yet: fall back to in place
        showPanel(items, below: true)
    }

    /// After expanding in place macOS silently drops the leftmost items behind the notch when the row is
    /// too long. Rescan once layout settled and put anything still off screen into the bar. In `.expanded`
    /// the always-hidden section is legitimately pushed away and must not count.
    private func showDroppedItems(after state: BarState) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard statusBar.state == state, !panel.isVisible else { return }
            let dropped = scan().filter { !$0.isOnScreen && (state == .all || section(of: $0) != .alwaysHidden) }
            Diagnostics.log("app", "dropped after \(state): \(dropped.map(\.title))")
            if !dropped.isEmpty { showPanel(dropped, below: false) }
        }
    }

    private func showPanel(_ items: [MenuBarItem], below: Bool) {
        guard let toggle = statusBar.toggleFrame, let screen = NSScreen.main else { return }
        panel.show(items: items, toggleFrame: toggle, on: screen, below: below)
    }

    // MARK: - Click forwarding

    private func forward(_ item: MenuBarItem) {
        panel.hide()
        let target: BarState = section(of: item) == .alwaysHidden ? .all : .expanded
        Task { @MainActor in
            // ponytail: stays expanded after the click; user collapses via the toggle.
            await ItemClicker.click(
                item,
                reveal: { self.statusBar.setState(target) },
                rescan: { self.scan().first { $0 == item } })
        }
    }

    // MARK: - Helpers

    private func scan() -> [MenuBarItem] { ItemScanner.scan() }

    private func section(of item: MenuBarItem) -> Section {
        guard let hidden = statusBar.hiddenSpacerFrame, let always = statusBar.alwaysHiddenSpacerFrame else {
            return .visible
        }
        return Layout.section(itemMinX: item.frame.minX, hiddenSpacerMinX: hidden.minX, alwaysHiddenSpacerMinX: always.minX)
    }
}
