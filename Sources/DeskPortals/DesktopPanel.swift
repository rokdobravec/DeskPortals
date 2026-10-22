import AppKit
import SwiftUI

/// Borderless panel that lives on the desktop layer: above the wallpaper and desktop icons,
/// below every normal window, on all Spaces, and left alone by Mission Control.
final class DesktopPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        isRestorable = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Hosting view that reacts to the first click even when DeskPortals isn't active.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Transparent area that drags the window (used behind the panel header).
struct WindowDragArea: NSViewRepresentable {
    var isEnabled: Bool

    final class DragView: NSView {
        var isEnabled = true
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override var mouseDownCanMoveWindow: Bool { false }
        override func mouseDown(with event: NSEvent) {
            guard isEnabled else { return }
            window?.performDrag(with: event)
        }
    }

    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ view: DragView, context: Context) { view.isEnabled = isEnabled }
}

/// Bottom-right grip that resizes the window while keeping its top edge in place.
struct ResizeGrip: NSViewRepresentable {
    static let minSize = NSSize(width: 180, height: 110)

    final class GripView: NSView {
        private var startFrame = NSRect.zero
        private var startMouse = NSPoint.zero

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override var mouseDownCanMoveWindow: Bool { false }

        override func mouseDown(with event: NSEvent) {
            startFrame = window?.frame ?? .zero
            startMouse = NSEvent.mouseLocation
        }

        override func mouseDragged(with event: NSEvent) {
            guard let window else { return }
            let mouse = NSEvent.mouseLocation
            let width = max(ResizeGrip.minSize.width, startFrame.width + mouse.x - startMouse.x)
            let height = max(ResizeGrip.minSize.height, startFrame.height - (mouse.y - startMouse.y))
            window.setFrame(
                NSRect(x: startFrame.minX, y: startFrame.maxY - height, width: width, height: height),
                display: true
            )
        }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.white.withAlphaComponent(0.35).setStroke()
            for inset in [3.0, 7.0] {
                let path = NSBezierPath()
                path.move(to: NSPoint(x: bounds.maxX - 3, y: bounds.minY + inset))
                path.line(to: NSPoint(x: bounds.minX + inset, y: bounds.maxY - 3))
                path.lineWidth = 1.2
                path.stroke()
            }
        }
    }

    func makeNSView(context: Context) -> GripView { GripView() }
    func updateNSView(_ view: GripView, context: Context) {}
}

/// Behind-window blur that stays "active" even when the panel isn't key.
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
