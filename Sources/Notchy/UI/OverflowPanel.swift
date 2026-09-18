import AppKit

/// Floating bar just below the menu bar showing hidden items as icon + title. Items that would
/// vanish behind the notch (too many to fit) are always reachable here.
@MainActor
final class OverflowPanel {
    var onSelect: ((MenuBarItem) -> Void)?
    var onDismiss: (() -> Void)?
    var isVisible: Bool { panel.isVisible }

    private let panel: KeyPanel
    private let content = NSVisualEffectView()
    private var monitor: Any?

    init() {
        panel = KeyPanel(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                         backing: .buffered, defer: true)
        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        content.material = .menu
        content.blendingMode = .behindWindow
        content.state = .active
        content.wantsLayer = true
        content.layer?.cornerRadius = 10
        content.layer?.masksToBounds = true
        panel.contentView = content
        panel.onCancel = { [weak self] in self?.dismiss() }
    }

    /// Shows (or refreshes) the panel right-aligned under `toggleFrame` (AppKit coords) on `screen`.
    /// Each cell is `item.icon` + `item.title`.
    func show(items: [MenuBarItem], toggleFrame: CGRect, on screen: NSScreen) {
        content.subviews.forEach { $0.removeFromSuperview() }
        let pad: CGFloat = 6, gap: CGFloat = 4, rowH: CGFloat = 22
        let maxRowWidth = screen.frame.width * 0.8

        // Greedy wrap into rows.
        var rows: [[ItemCell]] = [[]]
        var rowWidth: CGFloat = 0
        for item in items {
            let cell = ItemCell(item: item)
            cell.onClick = { [weak self] in self?.onSelect?($0) }
            let w = cell.frame.width
            if rowWidth > 0, rowWidth + gap + w > maxRowWidth { rows.append([]); rowWidth = 0 }
            rows[rows.count - 1].append(cell)
            rowWidth += (rowWidth > 0 ? gap : 0) + w
        }
        let rowWidths = rows.map { row in
            row.reduce(0) { $0 + $1.frame.width } + gap * CGFloat(max(row.count - 1, 0))
        }
        let width = (rowWidths.max() ?? 0) + 2 * pad
        let height = CGFloat(rows.count) * rowH + CGFloat(rows.count - 1) * gap + 2 * pad
        for (r, row) in rows.enumerated() {
            var x = pad
            let y = height - pad - rowH - CGFloat(r) * (rowH + gap)
            for cell in row {
                cell.frame.origin = CGPoint(x: x, y: y)
                content.addSubview(cell)
                x += cell.frame.width + gap
            }
        }

        let menuBarHeight = max(screen.frame.maxY - screen.visibleFrame.maxY, NSStatusBar.system.thickness)
        let visible = screen.visibleFrame
        var origin = CGPoint(x: toggleFrame.maxX - width, y: screen.frame.maxY - menuBarHeight - 4 - height)
        origin.x = min(max(origin.x, visible.minX), visible.maxX - width)
        origin.y = max(origin.y, visible.minY)
        panel.setFrame(CGRect(origin: origin, size: CGSize(width: width, height: height)), display: true)
        panel.orderFrontRegardless()
        panel.makeKey()

        if monitor == nil {
            monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor in self?.dismiss() }
            }
        }
    }

    func hide() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        panel.orderOut(nil)
    }

    private func dismiss() {
        guard isVisible else { return }
        hide()
        onDismiss?()
    }
}

/// Borderless panels refuse key status by default; we need it so Esc reaches `cancelOperation`.
private final class KeyPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { cancelOperation(self) } else { super.keyDown(with: event) }
    }
}

/// One menu bar item: 16 pt app icon + title, with hover highlight.
private final class ItemCell: NSView {
    let item: MenuBarItem
    var onClick: ((MenuBarItem) -> Void)?

    init(item: MenuBarItem) {
        self.item = item
        let h: CGFloat = 22
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        let icon = NSImageView(frame: CGRect(x: 3, y: 3, width: 16, height: 16))
        icon.image = item.icon
        let label = NSTextField(labelWithString: item.title)
        label.font = .menuBarFont(ofSize: 0)
        label.lineBreakMode = .byTruncatingTail
        label.sizeToFit()
        let labelWidth = min(label.frame.width, 140)
        label.frame = CGRect(x: 22, y: (h - label.frame.height) / 2, width: labelWidth, height: label.frame.height)
        addSubview(icon)
        addSubview(label)
        frame.size = CGSize(width: 22 + labelWidth + 4, height: h)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.35).cgColor
    }
    override func mouseExited(with event: NSEvent) { layer?.backgroundColor = nil }
    override func mouseUp(with event: NSEvent) { onClick?(item) }
}
