import SwiftUI

@MainActor
final class ExplorerModel: ObservableObject {
    struct Item: Identifiable, Hashable {
        let url: URL
        let isDir: Bool
        var size: Int64?
        let date: Date?
        var id: URL { url }
    }
    @Published var path = FS.home
    @Published var items: [Item] = []
    @Published var showHidden = false
    @Published var sizing = false
    private var token = CancelToken()
    private var task: Task<Void, Never>?

    var entries: [FileEntry] {
        items.map { FileEntry(url: $0.url, size: $0.size ?? 0, date: $0.date, isDir: $0.isDir, tag: nil) }
    }

    func load(_ url: URL) {
        token.cancel(); task?.cancel()
        token = CancelToken()
        path = url
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .totalFileAllocatedSizeKey, .fileSizeKey, .contentModificationDateKey]
        let opts: FileManager.DirectoryEnumerationOptions = showHidden ? [] : [.skipsHiddenFiles]
        let urls = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: opts)) ?? []
        items = urls.compactMap { u in
            guard let rv = try? u.resourceValues(forKeys: Set(keys)) else { return nil }
            let isDir = rv.isDirectory == true
            return Item(url: u, isDir: isDir, size: isDir ? nil : FS.fileSize(rv), date: rv.contentModificationDate)
        }
        sort()
        let dirs = items.filter { $0.isDir }.map(\.url)
        let tok = token
        sizing = !dirs.isEmpty
        task = Task { [weak self] in
            await withTaskGroup(of: (URL, Int64).self) { group in
                var next = 0
                func start(_ g: inout TaskGroup<(URL, Int64)>) {
                    guard next < dirs.count else { return }
                    let u = dirs[next]; next += 1
                    g.addTask { (u, FS.dirSize(u, cancel: tok)) }
                }
                for _ in 0..<min(4, dirs.count) { start(&group) }
                while let (u, s) = await group.next() {
                    if tok.isCancelled { break }
                    self?.setSize(u, s)
                    start(&group)
                }
                if tok.isCancelled { group.cancelAll() }
            }
            if !tok.isCancelled { self?.sizing = false }
        }
    }

    private func setSize(_ u: URL, _ s: Int64) {
        if let i = items.firstIndex(where: { $0.url == u }) { items[i].size = s }
        sort()
    }

    private func sort() {
        items.sort { ($0.size ?? -1) > ($1.size ?? -1) }
    }
}

struct ExplorerView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.pal) var pal
    @StateObject private var model = ExplorerModel()

    var body: some View {
        let maxSize = max(1, model.items.compactMap(\.size).max() ?? 1)
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: Section.explorer.title, lead: T("Ordner für Ordner nach Größe durchsuchen – wie eine Speicherverwaltung.", "Browse folder by folder, sorted by size – like a storage manager.")) {
                HStack {
                    Menu(T("Springen zu", "Jump to")) {
                        Button(T("Home-Ordner", "Home folder")) { state.selection.removeAll(); model.load(FS.home) }
                        Button("Macintosh HD") { state.selection.removeAll(); model.load(URL(fileURLWithPath: "/")) }
                        Button(T("Programme", "Applications")) { state.selection.removeAll(); model.load(URL(fileURLWithPath: "/Applications")) }
                        Button("Library") { state.selection.removeAll(); model.load(FS.library) }
                        Button(T("Externe Volumes", "External volumes")) { state.selection.removeAll(); model.load(URL(fileURLWithPath: "/Volumes")) }
                    }.fixedSize()
                    Toggle(T("Versteckte", "Hidden"), isOn: $model.showHidden).toggleStyle(.checkbox)
                        .onChange(of: model.showHidden) { _ in model.load(model.path) }
                }
            }.padding(.top, 28).padding(.bottom, 10)

            HStack(spacing: 6) {
                Button { go(model.path.deletingLastPathComponent()) } label: { Image(systemName: "chevron.up") }
                    .buttonStyle(PButtonStyle()).disabled(model.path.path == "/")
                breadcrumb
                Spacer()
                if model.sizing { ProgressView().controlSize(.small); Text(T("berechne Größen …", "calculating sizes …")).font(.system(size: 12)).foregroundColor(pal.mut) }
            }.padding(.bottom, 10)
            Line()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.items) { it in row(it, maxSize) ; Line().opacity(0.5) }
                }
            }
            SelectionBar(entries: model.entries)
        }
        .padding(.horizontal, 36).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { if model.items.isEmpty { model.load(FS.home) } }
    }

    private func go(_ u: URL) { state.selection.removeAll(); model.load(u) }

    private var breadcrumb: some View {
        let comps = model.path.pathComponents
        var parts: [(String, URL)] = []
        var cur = URL(fileURLWithPath: "/")
        parts.append(("Macintosh HD", cur))
        for c in comps.dropFirst() { cur = cur.appendingPathComponent(c); parts.append((c, cur)) }
        let shown = Array(parts.suffix(4))
        return HStack(spacing: 4) {
            if parts.count > 4 { Text("…").foregroundColor(pal.mut) }
            ForEach(Array(shown.enumerated()), id: \.offset) { i, p in
                if i > 0 || parts.count > 4 { Text("/").foregroundColor(pal.mut) }
                Button { go(p.1) } label: { Text(p.0).font(.mono(13, i == shown.count - 1 ? .semibold : .regular)) }
                    .buttonStyle(.plain).foregroundColor(i == shown.count - 1 ? pal.acc : pal.ink)
            }
        }
    }

    private func row(_ it: ExplorerModel.Item, _ maxSize: Int64) -> some View {
        let locked = Safety.isProtected(it.url)
        let on = state.selection.contains(it.url)
        let e = FileEntry(url: it.url, size: it.size ?? 0, date: it.date, isDir: it.isDir, tag: nil)
        return HStack(spacing: 0) {
            Button { if !locked { state.toggle(it.url) } } label: { Check(on: on, locked: locked) }.buttonStyle(.plain).padding(.trailing, 6)
            Image(nsImage: IconCache.icon(for: e)).resizable().frame(width: 22, height: 22).padding(.trailing, 8)
            Button { if it.isDir { go(it.url) } else { FS.open(it.url) } } label: {
                Text(it.url.lastPathComponent + (it.isDir ? "/" : "")).font(.mono(13, .medium)).lineLimit(1).truncationMode(.middle)
            }.buttonStyle(.plain).foregroundColor(it.isDir ? pal.ink : pal.ink)
            Spacer()
            if it.size == nil { ProgressView().controlSize(.mini).padding(.trailing, 8) }
            Text(it.size.map(formatBytes) ?? "").font(.mono(13)).frame(width: 90, alignment: .trailing)
            Text(Fmt.age(it.date)).font(.system(size: 12)).foregroundColor(pal.mut).frame(width: 150, alignment: .trailing)
            Button { FS.reveal(it.url) } label: { Image(systemName: "magnifyingglass") }.buttonStyle(.plain).foregroundColor(pal.mut).frame(width: 40)
        }
        .padding(.vertical, 6)
        .background(alignment: .leading) {
            Rectangle().fill(pal.acc.opacity(on ? 0.22 : 0.09))
                .scaleEffect(x: max(0.002, CGFloat(it.size ?? 0) / CGFloat(maxSize)), y: 1, anchor: .leading)
        }
        .contextMenu {
            Button(T("Im Finder zeigen", "Show in Finder")) { FS.reveal(it.url) }
            Button("Quick Look") { FS.quickLook(it.url) }
        }
    }
}
