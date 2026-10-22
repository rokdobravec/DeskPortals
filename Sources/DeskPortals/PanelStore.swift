import AppKit
import Observation

enum ViewMode: String, Codable, CaseIterable {
    case icons, list
}

/// Everything needed to restore one panel. Panels only reference a folder path; they never
/// copy, move or own the files inside it.
struct PanelConfig: Codable, Identifiable, Equatable {
    var id = UUID()
    var folderPath: String
    var title: String
    var frame: CGRect
    /// Height to restore when expanding a collapsed panel
    var expandedHeight: CGFloat
    var isCollapsed = false
    var isLocked = false
    var viewMode: ViewMode = .icons

    var folderURL: URL { URL(fileURLWithPath: folderPath, isDirectory: true) }
}

/// Persists panel configs as JSON in UserDefaults.
final class PanelStore {
    private let key = "panels.v1"

    func load() -> [PanelConfig] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let panels = try? JSONDecoder().decode([PanelConfig].self, from: data) else { return [] }
        return panels
    }

    func save(_ panels: [PanelConfig]) {
        guard let data = try? JSONEncoder().encode(panels) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

/// App-wide appearance and behavior settings, backed by UserDefaults.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    /// Darkness of the panel tint, 0.2–0.9
    var tintOpacity: Double {
        didSet { UserDefaults.standard.set(tintOpacity, forKey: "tintOpacity") }
    }
    var iconSize: Double {
        didSet { UserDefaults.standard.set(iconSize, forKey: "iconSize") }
    }
    var showHiddenFiles: Bool {
        didSet {
            UserDefaults.standard.set(showHiddenFiles, forKey: "showHiddenFiles")
            onListingOptionsChanged?()
        }
    }
    var foldersFirst: Bool {
        didSet {
            UserDefaults.standard.set(foldersFirst, forKey: "foldersFirst")
            onListingOptionsChanged?()
        }
    }

    @ObservationIgnored var onListingOptionsChanged: (() -> Void)?

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "tintOpacity": 0.45,
            "iconSize": 48.0,
            "showHiddenFiles": false,
            "foldersFirst": true,
        ])
        tintOpacity = defaults.double(forKey: "tintOpacity")
        iconSize = defaults.double(forKey: "iconSize")
        showHiddenFiles = defaults.bool(forKey: "showHiddenFiles")
        foldersFirst = defaults.bool(forKey: "foldersFirst")
    }
}
