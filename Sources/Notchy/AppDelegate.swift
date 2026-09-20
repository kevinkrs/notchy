import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController!
    private let panel = OverflowPanel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController()
        statusBar.setState(.collapsed)
        statusBar.onToggle = { [weak self] showAll in self?.toggle(showAll: showAll) }
        panel.onSelect = { [weak self] item in self?.forward(item) }
        panel.onDismiss = { [weak self] in
            // Panel closed without a click: nothing was revealed, stay collapsed.
            if self?.statusBar.state == .collapsed { self?.statusBar.setState(.collapsed) }
        }
        Diagnostics.log("app", "launched")
    }

    // MARK: - Toggle decision

    private func toggle(showAll: Bool) {
        if panel.isVisible { panel.hide() }
        if statusBar.state != .collapsed && !showAll {
            statusBar.setState(.collapsed)
            return
        }
        let target: BarState = showAll ? .all : .expanded
        let items = scan()
        Diagnostics.log("app", "toggle showAll=\(showAll) state=\(statusBar.state) toggle=\(Int(statusBar.toggleFrame?.minX ?? -1)) hidden=\(Int(statusBar.hiddenSpacerFrame?.minX ?? -1)) always=\(Int(statusBar.alwaysHiddenSpacerFrame?.minX ?? -1)) sections=\(items.map { "\($0.ownerName):\(section(of: $0))" })")
        let toReveal = items.filter { section(of: $0) == .hidden || (showAll && section(of: $0) == .alwaysHidden) }
        // Only the visible section between our hidden spacer and the toggle takes room from the hidden items;
        // system items right of the toggle are already outside `toggleMinX`.
        let toggleMinX = statusBar.toggleFrame?.minX ?? .greatestFiniteMagnitude
        let visible = items.filter { section(of: $0) == .visible && $0.frame.minX < toggleMinX }

        if toReveal.isEmpty || (!statusBar.alwaysUseBar && fits(toReveal, visible: visible)) {
            statusBar.setState(target)
            showDroppedItems(after: target)
            return
        }
        showPanel(toReveal)
    }

    /// Safety net after expanding in place: macOS silently drops the leftmost items behind the notch when
    /// the row is too long (AX widths can lie, Control Center items grow). Rescan once layout settled and
    /// put anything still off screen into the bar. In `.expanded` the always-hidden section is legitimately
    /// pushed away and must not count.
    private func showDroppedItems(after state: BarState) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard statusBar.state == state, !panel.isVisible else { return }
            let dropped = scan().filter { !$0.isOnScreen && (state == .all || section(of: $0) != .alwaysHidden) }
            Diagnostics.log("app", "dropped after \(state): \(dropped.map(\.title))")
            if !dropped.isEmpty { showPanel(dropped) }
        }
    }

    private func fits(_ hidden: [MenuBarItem], visible: [MenuBarItem]) -> Bool {
        guard let toggle = statusBar.toggleFrame, let screen = NSScreen.main else { return true }
        let leftBound = screen.auxiliaryTopRightArea?.minX ?? screen.frame.minX
        let available = Layout.availableWidth(
            toggleMinX: toggle.minX, leftBound: leftBound, visibleWidths: visible.map(\.frame.width))
        let ok = Layout.fits(hiddenWidths: hidden.map(\.frame.width), available: available)
        Diagnostics.log("app", "fit check: \(hidden.count) hidden, available \(Int(available)) → \(ok)")
        return ok
    }

    private func showPanel(_ items: [MenuBarItem]) {
        guard let toggle = statusBar.toggleFrame, let screen = NSScreen.main else { return }
        panel.show(items: items, toggleFrame: toggle, on: screen)
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
