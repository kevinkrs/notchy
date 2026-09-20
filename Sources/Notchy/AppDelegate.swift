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
        panel.onMove = { [weak self] item, section in self?.move(item, to: section) }
        panel.currentSection = { [weak self] item in self?.section(of: item) ?? .visible }
        panel.onDismiss = { [weak self] in
            // Panel closed without a click: nothing was revealed, stay collapsed.
            if self?.statusBar.state == .collapsed { self?.statusBar.setState(.collapsed) }
        }
        Diagnostics.log("app", "launched")
    }

    // MARK: - Toggle decision

    /// Click: expand in place, macOS shows as many hidden items as fit right of the notch. ⌥-click: same
    /// with the always-hidden section too (arrange mode, both dividers visible). "Always Use Bar": hidden
    /// items go to the bar left of the notch instead, nothing moves.
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
    }

    /// Right-click → "Show All Items": every hidden and always-hidden item in the panel below the toggle,
    /// menu bar untouched.
    private func showAllInPanel() {
        if panel.isVisible { return panel.hide() }
        let items = scan().filter { section(of: $0) != .visible }
        if items.isEmpty { return statusBar.setState(.all) } // no permission yet: fall back to in place
        showPanel(items, below: true)
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

    // MARK: - Moving between sections

    /// Collapse first: then nothing is dropped behind the notch, hidden sections are pushed to negative x
    /// where their windows are still grabbable, and both dividers have stable frames. Reopens Show All
    /// afterwards so the result is visible.
    private func move(_ item: MenuBarItem, to target: Section) {
        panel.hide()
        Task { @MainActor in
            if statusBar.state != .collapsed {
                statusBar.setState(.collapsed)
                try? await Task.sleep(for: .milliseconds(400))
            }
            guard let h = statusBar.hiddenSpacerFrame, let a = statusBar.alwaysHiddenSpacerFrame else { return }
            let moved = await ItemMover.move(
                item, to: target, dividers: .init(hidden: h, alwaysHidden: a),
                rescan: { self.scan().first { $0 == item } })
            if let after = self.scan().first(where: { $0 == item }) {
                Diagnostics.log("app", "\(item.title) moved=\(moved) now in \(self.section(of: after)) at \(Int(after.frame.minX))")
            }
            showAllInPanel()
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
