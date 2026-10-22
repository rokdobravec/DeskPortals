import AppKit
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let store = PanelStore()
    private var controllers: [PanelController] = []
    private var settingsWindow: NSWindow?
    private var launchAtLoginItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        controllers = store.load().map { makeController(for: ensureOnScreen($0)) }
        AppSettings.shared.onListingOptionsChanged = { [weak self] in
            self?.controllers.forEach { $0.contents.reload() }
        }
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "DeskPortals")

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(item(String(localized: "Add Panel…"), #selector(addPanel), key: "n"))
        menu.addItem(item(String(localized: "Settings…"), #selector(showSettings), key: ","))
        launchAtLoginItem = item(String(localized: "Launch at Login"), #selector(toggleLaunchAtLogin))
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Quit DeskPortals"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        launchAtLoginItem.state = LoginItem.isEnabled ? .on : .off
    }

    // MARK: - Panels

    private func makeController(for config: PanelConfig) -> PanelController {
        let controller = PanelController(config: config)
        controller.onChange = { [weak self] in self?.save() }
        controller.onRemove = { [weak self] in self?.removePanel($0) }
        return controller
    }

    private func save() {
        store.save(controllers.map(\.config))
    }

    @objc private func addPanel() {
        NSApp.activate()
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = true
        openPanel.prompt = String(localized: "Add Panel")
        openPanel.message = String(localized: "Choose one or more folders to show on the desktop")
        guard openPanel.runModal() == .OK else { return }

        let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let size = NSSize(width: 340, height: 280)
        for url in openPanel.urls {
            let offset = CGFloat(controllers.count % 8) * 28
            let frame = NSRect(
                x: visible.midX - size.width / 2 + offset,
                y: visible.midY - size.height / 2 - offset,
                width: size.width,
                height: size.height
            )
            let config = PanelConfig(
                folderPath: url.path,
                title: url.lastPathComponent,
                frame: frame,
                expandedHeight: size.height
            )
            controllers.append(makeController(for: config))
        }
        save()
    }

    private func removePanel(_ controller: PanelController) {
        controller.close()
        controllers.removeAll { $0 === controller }
        save()
    }

    /// Panels saved on a display that's no longer connected move back to the main screen.
    private func ensureOnScreen(_ config: PanelConfig) -> PanelConfig {
        guard !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(config.frame) }),
              let screen = NSScreen.main else { return config }
        var moved = config
        moved.frame.origin = NSPoint(
            x: screen.visibleFrame.midX - config.frame.width / 2,
            y: screen.visibleFrame.midY - config.frame.height / 2
        )
        return moved
    }

    // MARK: - Settings & login item

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = String(localized: "DeskPortals Settings")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try LoginItem.setEnabled(!LoginItem.isEnabled)
        } catch {
            NSApp.activate()
            NSAlert(error: error).runModal()
        }
    }
}

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
