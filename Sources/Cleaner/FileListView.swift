import SwiftUI

enum SortKey { case size, name, date }

struct FileListView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.pal) var pal

    let entries: [FileEntry]
    var emptyText: String = T("Nichts gefunden.", "Nothing found.")
    var dateTitle: String = T("Zuletzt benutzt", "Last used")
    var selectable = true
    var showTagFilter = true
    var rowButtonTitle: String? = nil
    var onRowButton: ((FileEntry) -> Void)? = nil
    var allowTrash = true

    @StateObject private var ui = ListUI()
    private var sortKey: SortKey { get { ui.sortKey } nonmutating set { ui.sortKey = newValue } }
    private var ascending: Bool { get { ui.ascending } nonmutating set { ui.ascending = newValue } }
    private var query: String { get { ui.query } nonmutating set { ui.query = newValue } }
    private var tag: String? { get { ui.tag } nonmutating set { ui.tag = newValue } }

    private let cap = 1000

    private var shown: [FileEntry] {
        var list = entries
        if let tag { list = list.filter { $0.tag == tag } }
        if !query.isEmpty { list = list.filter { $0.url.path.localizedCaseInsensitiveContains(query) } }
        list.sort { a, b in
            let c: Int
            switch sortKey {
            case .size: c = a.size == b.size ? 0 : (a.size < b.size ? -1 : 1)
            case .name: c = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending ? -1 : (a.name.localizedCaseInsensitiveCompare(b.name) == .orderedSame ? 0 : 1)
            case .date:
                let x = a.date ?? .distantPast, y = b.date ?? .distantPast
                c = x == y ? 0 : (x < y ? -1 : 1)
            }
            if c == 0 { return a.url.path < b.url.path }
            return ascending ? c < 0 : c > 0
        }
        return list
    }

    private var tags: [String] { Array(Set(entries.compactMap(\.tag))).sorted() }

    var body: some View {
        let list = shown
        let visible = Array(list.prefix(cap))
        let maxSize = max(1, list.map(\.size).max() ?? 1)
        VStack(spacing: 0) {
            toolbar(list)
            headerRow(list)
            Line()
            if visible.isEmpty {
                Text(emptyText).foregroundColor(pal.mut).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visible) { e in
                            FileRow(entry: e, maxSize: maxSize, selectable: selectable,
                                    showTag: showTagFilter && e.tag != nil,
                                    rowButtonTitle: rowButtonTitle, onRowButton: onRowButton)
                            Line().opacity(0.5)
                        }
                        if list.count > cap {
                            Text(T("… \(list.count - cap) weitere – Suche oder Filter nutzen.", "… \(list.count - cap) more – use search or filter."))
                                .font(.system(size: 12)).foregroundColor(pal.mut).padding(12)
                        }
                    }
                }
            }
            if selectable { SelectionBar(entries: entries, allowTrash: allowTrash) }
        }
    }

    private func toolbar(_ list: [FileEntry]) -> some View {
        HStack(spacing: 10) {
            PField(placeholder: T("Suchen …", "Search …"), text: $ui.query)
            if showTagFilter && tags.count > 1 {
                Button { tag = nil } label: { Chip(text: T("Alle", "All"), active: tag == nil) }.buttonStyle(.plain)
                ForEach(tags, id: \.self) { t in
                    Button { tag = (tag == t ? nil : t) } label: { Chip(text: tagLabel(t), active: tag == t) }.buttonStyle(.plain)
                }
            }
            Spacer()
            Text("\(list.count) · \(formatBytes(list.reduce(0) { $0 + $1.size }))")
                .font(.mono(12)).foregroundColor(pal.mut)
            if selectable {
                Button(T("Alle wählen", "Select all")) {
                    let ok = list.prefix(cap).filter { !Safety.isProtected($0.url) }.map(\.url)
                    state.selection.formUnion(ok)
                }.buttonStyle(PButtonStyle())
            }
        }.padding(.bottom, 10)
    }

    private func headerRow(_ list: [FileEntry]) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: selectable ? 54 : 32)
            sortButton(T("Name", "Name"), .name).frame(maxWidth: .infinity, alignment: .leading)
            sortButton(T("Größe", "Size"), .size).frame(width: 90, alignment: .trailing)
            sortButton(dateTitle, .date).frame(width: 150, alignment: .trailing)
            Color.clear.frame(width: rowButtonTitle == nil ? 64 : 150)
        }
        .font(.system(size: 12, weight: .semibold)).foregroundColor(pal.mut).padding(.vertical, 6)
    }

    private func sortButton(_ title: String, _ key: SortKey) -> some View {
        Button {
            if sortKey == key { ascending.toggle() } else { sortKey = key; ascending = (key == .name) }
        } label: {
            Text(title + (sortKey == key ? (ascending ? " ↑" : " ↓") : ""))
                .foregroundColor(sortKey == key ? pal.acc : pal.mut)
        }.buttonStyle(.plain)
    }
}

struct FileRow: View {
    @EnvironmentObject var state: AppState
    @Environment(\.pal) var pal
    let entry: FileEntry
    let maxSize: Int64
    let selectable: Bool
    let showTag: Bool
    var rowButtonTitle: String?
    var onRowButton: ((FileEntry) -> Void)?

    var body: some View {
        let locked = Safety.isProtected(entry.url)
        let on = state.selection.contains(entry.url)
        HStack(spacing: 0) {
            if selectable {
                Check(on: on, locked: locked).padding(.trailing, 6)
            }
            Image(nsImage: IconCache.icon(for: entry)).resizable().frame(width: 22, height: 22).padding(.trailing, 8)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(entry.name).font(.mono(13, .medium)).lineLimit(1).truncationMode(.middle).foregroundColor(pal.ink)
                    if showTag, let t = entry.tag { Chip(text: tagLabel(t)) }
                }
                Text(FS.displayPath(entry.url)).font(.system(size: 11)).foregroundColor(pal.mut).lineLimit(1).truncationMode(.middle)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Text(formatBytes(entry.size)).font(.mono(13)).foregroundColor(pal.ink).frame(width: 90, alignment: .trailing)
            Text(Fmt.age(entry.date)).font(.system(size: 12)).foregroundColor(pal.mut).frame(width: 150, alignment: .trailing)
            HStack(spacing: 4) {
                if let title = rowButtonTitle, let act = onRowButton {
                    Button(title) { act(entry) }.buttonStyle(PButtonStyle()).disabled(locked)
                }
                Button { FS.reveal(entry.url) } label: { Image(systemName: "magnifyingglass") }
                    .buttonStyle(.plain).help(T("Im Finder zeigen", "Show in Finder")).foregroundColor(pal.mut)
                Button { FS.quickLook(entry.url) } label: { Image(systemName: "eye") }
                    .buttonStyle(.plain).help("Quick Look").foregroundColor(pal.mut)
            }.frame(width: rowButtonTitle == nil ? 64 : 150, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .background(alignment: .leading) {
            Rectangle().fill(pal.acc.opacity(on ? 0.22 : 0.09))
                .scaleEffect(x: max(0.002, CGFloat(entry.size) / CGFloat(maxSize)), y: 1, anchor: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture { if selectable && !locked { state.toggle(entry.url) } }
        .contextMenu {
            Button(T("Im Finder zeigen", "Show in Finder")) { FS.reveal(entry.url) }
            Button(T("Öffnen", "Open")) { FS.open(entry.url) }
            Button("Quick Look") { FS.quickLook(entry.url) }
            Button(T("Pfad kopieren", "Copy path")) {
                NSPasteboard.general.clearContents(); NSPasteboard.general.setString(entry.url.path, forType: .string)
            }
            if selectable && !locked {
                Divider()
                Button(T("Ignorieren (nie wieder anzeigen)", "Ignore (never show again)")) { state.ignore(entry.url) }
                Button(T("In den Papierkorb …", "Move to Trash …")) { state.requestDelete([entry], permanent: false) }
            }
        }
    }
}

struct SelectionBar: View {
    @EnvironmentObject var state: AppState
    @Environment(\.pal) var pal
    let entries: [FileEntry]
    var allowTrash = true

    var body: some View {
        let sel = entries.filter { state.selection.contains($0.url) }
        if !sel.isEmpty {
            VStack(spacing: 0) {
                Line()
                HStack(spacing: 10) {
                    Text(T("\(sel.count) ausgewählt", "\(sel.count) selected") + " · " + formatBytes(sel.reduce(0) { $0 + $1.size }))
                        .font(.mono(13, .semibold)).foregroundColor(pal.ink)
                    Spacer()
                    Button(T("Auswahl aufheben", "Clear selection")) { state.selection.removeAll() }.buttonStyle(PButtonStyle())
                    if allowTrash {
                        Button(T("In den Papierkorb", "Move to Trash")) { state.requestDelete(sel, permanent: false) }.buttonStyle(PButtonStyle(kind: .primary))
                    }
                    Button(T("Endgültig löschen", "Delete permanently")) { state.requestDelete(sel, permanent: true) }.buttonStyle(PButtonStyle(kind: .danger))
                }.padding(.vertical, 10)
            }.background(pal.paper)
        }
    }
}
