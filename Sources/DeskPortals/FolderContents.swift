import AppKit
import Observation

struct FileItem: Identifiable, Equatable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let modified: Date?

    var id: URL { url }
}

/// Live, read-only listing of one folder's top level, refreshed by FSEvents.
@Observable
final class FolderContents {
    private(set) var items: [FileItem] = []
    private(set) var folderExists = true

    @ObservationIgnored private(set) var url: URL
    @ObservationIgnored private var watcher: FolderWatcher?
    @ObservationIgnored private var iconCache: [URL: NSImage] = [:]

    init(url: URL) {
        self.url = url
        start()
    }

    func changeFolder(to newURL: URL) {
        url = newURL
        iconCache.removeAll()
        start()
    }

    func icon(for item: FileItem) -> NSImage {
        if let cached = iconCache[item.url] { return cached }
        let icon = NSWorkspace.shared.icon(forFile: item.url.path)
        iconCache[item.url] = icon
        return icon
    }

    func reload() {
        let settings = AppSettings.shared
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .contentModificationDateKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: settings.showHiddenFiles ? [] : [.skipsHiddenFiles]
        ) else {
            folderExists = false
            items = []
            return
        }
        folderExists = true

        var newItems = urls.map { fileURL -> FileItem in
            let values = try? fileURL.resourceValues(forKeys: Set(keys))
            // Packages (apps, bundles) behave like files
            let isFolder = (values?.isDirectory ?? false) && !(values?.isPackage ?? false)
            return FileItem(
                url: fileURL,
                name: FileManager.default.displayName(atPath: fileURL.path),
                isDirectory: isFolder,
                modified: values?.contentModificationDate
            )
        }
        newItems.sort { a, b in
            if settings.foldersFirst, a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }

        // Drop cached icons for items that are gone; refresh icons of changed items
        let current = Set(newItems.map(\.url))
        iconCache = iconCache.filter { current.contains($0.key) }
        for item in newItems where items.first(where: { $0.url == item.url })?.modified != item.modified {
            iconCache[item.url] = nil
        }
        if newItems != items { items = newItems }
    }

    private func start() {
        watcher = FolderWatcher(url: url) { [weak self] in self?.reload() }
        reload()
    }
}
