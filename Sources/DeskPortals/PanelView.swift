import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PanelView: View {
    let controller: PanelController
    private let settings = AppSettings.shared

    @State private var selection: URL?
    @State private var isDropTargeted = false

    private var config: PanelConfig { controller.config }

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: PanelController.headerHeight)
            if !config.isCollapsed {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            ZStack {
                VisualEffectBackground()
                Color.black.opacity(settings.tintOpacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color.white.opacity(0.12),
                    lineWidth: isDropTargeted ? 2 : 1
                )
        }
        .overlay(alignment: .bottomTrailing) {
            if !config.isCollapsed && !config.isLocked {
                ResizeGrip()
                    .frame(width: 14, height: 14)
                    .padding(3)
                    .help("Drag to resize")
            }
        }
        .environment(\.colorScheme, .dark)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Button {
                controller.toggleCollapsed()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .rotationEffect(.degrees(config.isCollapsed ? -90 : 0))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(config.isCollapsed ? "Expand" : "Collapse")

            Text(config.title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)

            Text(controller.contents.items.count.formatted())
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 4)

            Button {
                controller.toggleLocked()
            } label: {
                Image(systemName: config.isLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 11))
                    .foregroundStyle(config.isLocked ? .primary : .secondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(config.isLocked ? "Unlock position and size" : "Lock position and size")

            Menu {
                panelMenu
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 12))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Panel options")
        }
        .padding(.horizontal, 8)
        .foregroundStyle(.primary)
        .background(WindowDragArea(isEnabled: !config.isLocked))
    }

    @ViewBuilder
    private var panelMenu: some View {
        Picker("View", selection: Binding(get: { config.viewMode }, set: { controller.setViewMode($0) })) {
            Label("Icons", systemImage: "square.grid.2x2").tag(ViewMode.icons)
            Label("List", systemImage: "list.bullet").tag(ViewMode.list)
        }
        .pickerStyle(.inline)
        Divider()
        Button("Rename…") { controller.rename() }
        Button("Change Folder…") { controller.chooseFolder() }
        Button("Show in Finder") { controller.showInFinder() }
        Button(config.isLocked ? "Unlock" : "Lock") { controller.toggleLocked() }
        Divider()
        Button("Remove Panel") { controller.remove() }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let contents = controller.contents
        if !contents.folderExists {
            VStack(spacing: 6) {
                Image(systemName: "questionmark.folder")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                Text("Folder not found")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button("Choose Folder…") { controller.chooseFolder() }
                    .controlSize(.small)
            }
        } else if contents.items.isEmpty {
            Text("Empty folder\nDrop files here to copy them in")
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(.tertiary)
        } else {
            ScrollView {
                switch config.viewMode {
                case .icons:
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: settings.iconSize + 28), spacing: 4, alignment: .top)],
                        spacing: 6
                    ) {
                        ForEach(contents.items) { cell(for: $0) }
                    }
                    .padding(8)
                case .list:
                    LazyVStack(spacing: 0) {
                        ForEach(contents.items) { cell(for: $0) }
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollIndicators(.automatic)
        }
    }

    private func cell(for item: FileItem) -> some View {
        ItemCell(
            item: item,
            icon: controller.contents.icon(for: item),
            mode: config.viewMode,
            iconSize: settings.iconSize,
            isSelected: selection == item.url
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { controller.open(item) }
        .simultaneousGesture(TapGesture().onEnded { selection = item.url })
        // Drag out offers a file URL; the drop target decides to copy, the panel never moves it
        .onDrag { NSItemProvider(object: item.url as NSURL) }
        .contextMenu {
            Button("Open") { controller.open(item) }
            Button("Show in Finder") { controller.showInFinder(item.url) }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.path, forType: .string)
            }
        }
        .help(item.name)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else { return false }
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []
        for provider in fileProviders {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { controller.copyIntoFolder(urls) }
        return true
    }
}

struct ItemCell: View {
    let item: FileItem
    let icon: NSImage
    let mode: ViewMode
    let iconSize: Double
    let isSelected: Bool

    var body: some View {
        switch mode {
        case .icons:
            VStack(spacing: 3) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: iconSize, height: iconSize)
                Text(item.name)
                    .font(.system(size: 11))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
            }
            .padding(4)
            .frame(width: iconSize + 28)
            .background(selectionBackground)
        case .list:
            HStack(spacing: 8) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 18, height: 18)
                Text(item.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                if let modified = item.modified {
                    Text(modified.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(selectionBackground)
        }
    }

    private var selectionBackground: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.4) : .clear)
    }
}
