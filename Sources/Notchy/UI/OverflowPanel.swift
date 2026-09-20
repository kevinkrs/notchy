import AppKit

/// Bar showing hidden items as app icons. Items that would vanish behind the notch (too many to
/// fit) are always reachable here. Preferred placement: inside the menu bar, in the free strip left of
/// the notch (like Ice / Bartender). Fallback: floating panel just below the menu bar under the toggle.
@MainActor
final class OverflowPanel {
    var onSelect: ((MenuBarItem) -> Void)?
    var onDismiss: (() -> Void)?
    var isVisible: Bool { panel.isVisible }

    private let panel: KeyPanel
    private let content = NSView()
    private let backdrop = NSVisualEffectView()
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
        backdrop.material = .menu
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.wantsLayer = true
        backdrop.layer?.cornerRadius = 10
        backdrop.layer?.masksToBounds = true
        backdrop.autoresizingMask = [.width, .height]
        content.addSubview(backdrop)
        panel.contentView = content
        panel.onCancel = { [weak self] in self?.dismiss() }
    }

    /// Shows (or refreshes) the bar. Left of the notch inside the menu bar when everything fits in one
    /// row there, else (or when `below`) right-aligned under `toggleFrame` (AppKit coords) on `screen`.
    func show(items: [MenuBarItem], toggleFrame: CGRect, on screen: NSScreen, below: Bool = false) {
        content.subviews.filter { $0 !== backdrop }.forEach { $0.removeFromSuperview() }
        let pad: CGFloat = 6, gap: CGFloat = 4, rowH: CGFloat = 22
        let cells = items.map { item in
            let cell = ItemCell(item: item)
            cell.onClick = { [weak self] in self?.onSelect?($0) }
            return cell
        }
        let menuBarHeight = max(screen.frame.maxY - screen.visibleFrame.maxY, NSStatusBar.system.thickness)

        // 1. Menu bar strip left of the notch: one row, no backdrop, looks like native items.
        let oneRow = cells.reduce(0) { $0 + $1.frame.width } + gap * CGFloat(max(cells.count - 1, 0))
        if !below, let area = screen.auxiliaryTopLeftArea,
           let x = Layout.leftOfNotchX(area: area, appMenuMaxX: ItemScanner.frontmostMenuMaxX() ?? area.minX, width: oneRow) {
            backdrop.isHidden = true
            panel.hasShadow = false
            layOut([cells], gap: gap, rowH: rowH, pad: 0, height: menuBarHeight)
            panel.setFrame(CGRect(x: x, y: screen.frame.maxY - menuBarHeight, width: oneRow, height: menuBarHeight), display: true)
            Diagnostics.log("panel", "left of notch at \(Int(x)) width \(Int(oneRow))")
            return present()
        }

        // 2. Floating panel below the menu bar: greedy wrap into rows.
        backdrop.isHidden = false
        panel.hasShadow = true
        let maxRowWidth = screen.frame.width * 0.8
        var rows: [[ItemCell]] = [[]]
        var rowWidth: CGFloat = 0
        for cell in cells {
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
        layOut(rows, gap: gap, rowH: rowH, pad: pad, height: height)

        let visible = screen.visibleFrame
        var origin = CGPoint(x: toggleFrame.maxX - width, y: screen.frame.maxY - menuBarHeight - 4 - height)
        origin.x = min(max(origin.x, visible.minX), visible.maxX - width)
        origin.y = max(origin.y, visible.minY)
        panel.setFrame(CGRect(origin: origin, size: CGSize(width: width, height: height)), display: true)
        present()
    }

    /// Rows top-down, cells left-to-right. A single row is vertically centred in `height`.
    private func layOut(_ rows: [[ItemCell]], gap: CGFloat, rowH: CGFloat, pad: CGFloat, height: CGFloat) {
        for (r, row) in rows.enumerated() {
            var x = pad
            let y = rows.count == 1 ? (height - rowH) / 2 : height - pad - rowH - CGFloat(r) * (rowH + gap)
            for cell in row {
                cell.frame.origin = CGPoint(x: x, y: y)
                content.addSubview(cell)
                x += cell.frame.width + gap
            }
        }
    }

    private func present() {
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

/// One menu bar item: 16 pt app icon with hover highlight, title in the tooltip.
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
        addSubview(icon)
        toolTip = item.title
        frame.size = CGSize(width: h, height: h)
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
