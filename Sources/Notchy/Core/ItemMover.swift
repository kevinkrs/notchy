import AppKit
import ApplicationServices

/// Moves another app's item into a section by faking the only thing macOS accepts: a ⌘-drag in the
/// menu bar. Ice's recipe: ⌘-mouse-down at the item's frame, mouse-up at the destination, both posted to
/// the session event tap, no dragged events. The item does not have to be on screen: items pushed off by
/// a spacer keep live windows at their negative x. Items macOS drops behind the notch do not, so callers
/// collapse first (everything hidden is pushed, nothing is dropped).
@MainActor
enum ItemMover {
    struct Dividers { let hidden: CGRect; let alwaysHidden: CGRect } // AppKit frames, only x is used

    /// Drop x just beside the divider that bounds `section` on the right (hidden / always hidden) or the
    /// hidden divider's right edge (visible). Works in every state as long as the dividers are not
    /// dropped behind the notch, hence `.collapsed`.
    static func destinationX(for section: Section, dividers d: Dividers) -> CGFloat {
        switch section {
        case .visible: d.hidden.maxX + 4
        case .hidden: d.hidden.minX - 4
        case .alwaysHidden: d.alwaysHidden.minX - 4
        }
    }

    /// Returns true when the item's frame changed. Retries up to three times (Ice does five).
    static func move(_ item: MenuBarItem, to section: Section, dividers: Dividers,
                     rescan: @MainActor () -> MenuBarItem?) async -> Bool {
        let targetX = destinationX(for: section, dividers: dividers)
        let cursor = NSEvent.mouseLocation
        defer { restoreCursor(cursor) }
        // Ice's recipe verbatim: HID-state source, local event filter permitting everything while the
        // synthetic drag is in flight, mouse-down at a bogus far-away point (routing is done purely by the
        // stamped window fields, no hit test), mouse-up at the destination stamped with the window there.
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }
        let permitAll: CGEventFilterMask = [.permitLocalMouseEvents, .permitLocalKeyboardEvents, .permitSystemDefinedEvents]
        source.setLocalEventsFilterDuringSuppressionState(permitAll, state: .eventSuppressionStateRemoteMouseDrag)
        source.setLocalEventsFilterDuringSuppressionState(permitAll, state: .eventSuppressionStateSuppressionInterval)
        source.localEventsSuppressionInterval = 0
        for attempt in 1...4 {
            guard let fresh = rescan() else { return false }
            let from = CGPoint(x: fresh.frame.midX, y: fresh.frame.midY)
            let to = CGPoint(x: targetX, y: from.y)
            guard let win = statusWindow(at: from) else {
                Diagnostics.log("mover", "\(fresh.title): no status window at \(Int(from.x))")
                return false
            }
            let destWin = statusWindow(at: to) ?? win
            let viaPid = attempt.isMultiple(of: 2) // odd attempts: session tap (Ice); even: straight to the owner
            Diagnostics.log("mover", "\(fresh.title) #\(attempt) from \(Int(from.x)) to \(Int(targetX)) [\(section)] win=\(win.id)→\(destWin.id) pid=\(win.pid) \(viaPid ? "postToPid" : "session")")
            post(.leftMouseDown, CGPoint(x: 20_000, y: 20_000), flags: .maskCommand, window: win, pid: win.pid, source: source, viaPid: viaPid)
            // Wait for the grab to register (Ice: frame change within 50 ms).
            for _ in 0..<5 {
                try? await Task.sleep(for: .milliseconds(20))
                if rescan()?.frame != fresh.frame { break }
            }
            post(.leftMouseUp, to, flags: [], window: destWin, pid: win.pid, source: source, viaPid: viaPid)
            try? await Task.sleep(for: .milliseconds(150))
            if let after = rescan(), after.frame.minX != fresh.frame.minX {
                Diagnostics.log("mover", "\(fresh.title) moved to \(Int(after.frame.minX))")
                return true
            }
        }
        Diagnostics.log("mover", "\(item.title): frame unchanged after 4 attempts")
        return false
    }

    struct StatusWindow { let id: CGWindowID; let pid: pid_t }

    /// Status bar window (layer 25) whose bounds contain `point` (Quartz). `.optionAll` includes the
    /// off-screen ones a spacer pushed away.
    static func statusWindow(at point: CGPoint) -> StatusWindow? {
        let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        for w in list where (w[kCGWindowLayer as String] as? Int) == 25 {
            guard let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = b["X"], let width = b["Width"], width > 0, x <= point.x, point.x < x + width,
                  let id = w[kCGWindowNumber as String] as? CGWindowID,
                  let pid = w[kCGWindowOwnerPID as String] as? pid_t else { continue }
            return StatusWindow(id: id, pid: pid)
        }
        return nil
    }

    private static func post(_ type: CGEventType, _ p: CGPoint, flags: CGEventFlags, window: StatusWindow, pid: pid_t,
                             source: CGEventSource, viaPid: Bool) {
        guard let e = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: p, mouseButton: .left) else { return }
        e.flags = flags
        e.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(pid))
        e.setIntegerValueField(.eventSourceUserData, value: Int64(truncatingIfNeeded: Int(bitPattern: ObjectIdentifier(e))))
        e.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(window.id))
        e.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: Int64(window.id))
        e.setIntegerValueField(CGEventField(rawValue: 0x33)!, value: Int64(window.id)) // private "windowID" field Ice sets
        if viaPid { e.postToPid(pid) } else { e.post(tap: .cgSessionEventTap) }
    }

    /// `NSEvent.mouseLocation` is AppKit (bottom-left origin); warp wants Quartz.
    private static func restoreCursor(_ appKit: CGPoint) {
        guard let screen = NSScreen.screens.first else { return }
        CGWarpMouseCursorPosition(CGPoint(x: appKit.x, y: screen.frame.maxY - appKit.y))
    }
}
