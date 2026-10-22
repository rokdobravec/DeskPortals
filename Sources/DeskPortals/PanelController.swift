import AppKit
import Observation
import SwiftUI

/// Owns one desktop panel: its window, its folder listing and its saved config.
@Observable
final class PanelController {
    static let headerHeight: CGFloat = 34

    var config: PanelConfig {
        didSet { if config != oldValue { onChange?() } }
    }
    let contents: FolderContents

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored var onRemove: ((PanelController) -> Void)?
    @ObservationIgnored private var panel: DesktopPanel!
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(config: PanelConfig) {
        self.config = config
        contents = FolderContents(url: config.folderURL)

        let height = config.isCollapsed ? Self.headerHeight : config.expandedHeight
        let frame = NSRect(x: config.frame.minX, y: config.frame.maxY - height, width: config.frame.width, height: height)
        panel = DesktopPanel(contentRect: frame)
        let hostingView = FirstClickHostingView(rootView: PanelView(controller: self))
        hostingView.sizingOptions = [] // the panel's size is ours, not the content's
        panel.contentView = hostingView

        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: panel, queue: .main) { [weak self] _ in
                self?.syncFrame()
            })
        }
        panel.orderFront(nil)
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func close() {
        panel.orderOut(nil)
        panel.close()
    }

    /// PNG of the panel's current contents (debug snapshots)
    func snapshotPNG() -> Data? {
        guard let view = panel.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
    }

    private func syncFrame() {
        var updated = config
        updated.frame = panel.frame
        if !updated.isCollapsed { updated.expandedHeight = panel.frame.height }
        config = updated
    }

    // MARK: - Panel actions

    func toggleCollapsed() {
        config.isCollapsed.toggle()
        let height = config.isCollapsed ? Self.headerHeight : config.expandedHeight
        let frame = panel.frame
        panel.setFrame(
            NSRect(x: frame.minX, y: frame.maxY - height, width: frame.width, height: height),
            display: true,
            animate: true
        )
    }

    func toggleLocked() {
        config.isLocked.toggle()
    }

    func setViewMode(_ mode: ViewMode) {
        config.viewMode = mode
    }

    func rename() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = String(localized: "Rename Panel")
        alert.addButton(withTitle: String(localized: "Rename"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        let field = NSTextField(string: config.title)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let title = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { config.title = title }
    }

    func chooseFolder() {
        NSApp.activate()
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.directoryURL = config.folderURL
        openPanel.prompt = String(localized: "Show Folder")
        guard openPanel.runModal() == .OK, let url = openPanel.url else { return }
        let oldName = config.folderURL.lastPathComponent
        config.folderPath = url.path
        if config.title == oldName { config.title = url.lastPathComponent }
        contents.changeFolder(to: url)
    }

    func showInFinder(_ url: URL? = nil) {
        NSWorkspace.shared.activateFileViewerSelecting([url ?? config.folderURL])
    }

    func remove() {
        onRemove?(self)
    }

    // MARK: - Files

    func open(_ item: FileItem) {
        NSWorkspace.shared.open(item.url)
    }

    /// Copies dropped files into the panel's folder. Originals are never moved; name clashes
    /// get a " 2", " 3"… suffix instead of overwriting.
    func copyIntoFolder(_ urls: [URL]) {
        let folder = config.folderURL.standardizedFileURL
        let sources = urls.map(\.standardizedFileURL).filter { source in
            source.deletingLastPathComponent() != folder        // already here
                && source != folder
                && !folder.path.hasPrefix(source.path + "/")    // a folder into itself
        }
        guard !sources.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            var failures: [String] = []
            for source in sources {
                do {
                    try FileManager.default.copyItem(at: source, to: Self.uniqueDestination(for: source, in: folder))
                } catch {
                    failures.append("\(source.lastPathComponent): \(error.localizedDescription)")
                }
            }
            guard !failures.isEmpty else { return }
            DispatchQueue.main.async {
                NSApp.activate()
                let alert = NSAlert()
                alert.messageText = String(localized: "Some files couldn't be copied")
                alert.informativeText = failures.joined(separator: "\n")
                alert.runModal()
            }
        }
    }

    private static func uniqueDestination(for source: URL, in folder: URL) -> URL {
        let ext = source.pathExtension
        let base = source.deletingPathExtension().lastPathComponent
        var candidate = folder.appendingPathComponent(source.lastPathComponent)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            candidate = folder.appendingPathComponent(name)
            n += 1
        }
        return candidate
    }
}
