import SwiftUI

private let pageH: CGFloat = 36

struct Page<Content: View>: View {
    let title: String
    let lead: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: title, lead: lead).padding(.top, 28).padding(.bottom, 14)
            content
        }.padding(.horizontal, pageH).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct LargeView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var settings: Settings
    var body: some View {
        Page(title: Section.large.title, lead: T("Alles ab \(settings.largeMB) MB, nach Größe sortiert – die schnellsten Platzgewinne.", "Everything from \(settings.largeMB) MB, sorted by size – the quickest wins.")) {
            FileListView(entries: state.large, dateTitle: T("Zuletzt geändert", "Last modified"), showTagFilter: false)
        }
    }
}

struct StaleView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var settings: Settings
    var body: some View {
        Page(title: Section.stale.title, lead: T("Dokumente, die seit über \(settings.staleDays) Tagen weder geöffnet noch geändert wurden.", "Documents neither opened nor modified for over \(settings.staleDays) days.")) {
            FileListView(entries: state.stale, emptyText: T("Keine veralteten Dokumente gefunden.", "No outdated documents found."), dateTitle: T("Zuletzt benutzt", "Last used"), showTagFilter: false)
        }
    }
}

struct DownloadsView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        Page(title: Section.downloads.title, lead: T("Alles in deinem Downloads-Ordner – meist voller Installer und Altlasten.", "Everything in your Downloads folder – usually full of installers and leftovers.")) {
            FileListView(entries: state.downloads, dateTitle: T("Zuletzt geändert", "Last modified"), showTagFilter: false)
        }
    }
}

struct CachesView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        Page(title: Section.caches.title, lead: T("App-Caches, Protokolle, Xcode-Altlasten und iOS-Backups. Caches baut macOS bei Bedarf neu auf.", "App caches, logs, Xcode leftovers and iOS backups. macOS rebuilds caches as needed.")) {
            FileListView(entries: state.caches, dateTitle: T("Zuletzt geändert", "Last modified"))
        }
    }
}

struct AppsView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        Page(title: Section.apps.title, lead: T("Installierte Programme nach Größe. „Deinstallieren“ räumt auch Reste in ~/Library auf.", "Installed apps by size. “Uninstall” also removes leftovers in ~/Library.")) {
            FileListView(entries: state.apps, emptyText: T("Keine Apps gefunden.", "No apps found."),
                         dateTitle: T("Zuletzt geöffnet", "Last opened"), selectable: false, showTagFilter: false,
                         rowButtonTitle: T("Deinstallieren …", "Uninstall …")) { state.uninstallTarget = $0 }
        }
    }
}

struct TrashView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.pal) var pal
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: Section.trash.title, lead: T("Erst nach dem Leeren wird der Platz wirklich frei.", "Space is only freed once the Trash is emptied.")) {
                Button(T("Papierkorb leeren …", "Empty Trash …")) {
                    state.requestDelete(state.trash, permanent: true)
                }.buttonStyle(PButtonStyle(kind: .danger)).disabled(state.trash.isEmpty)
            }.padding(.top, 28).padding(.bottom, 14)
            if state.trashDenied {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(T("Kein Zugriff auf den Papierkorb.", "No access to the Trash.")).font(.system(size: 14, weight: .semibold))
                        Text(T("Gib Cleaner unter Systemeinstellungen → Datenschutz & Sicherheit → Voller Festplattenzugriff die Berechtigung.", "Grant Cleaner access under System Settings → Privacy & Security → Full Disk Access."))
                            .foregroundColor(pal.mut)
                        Button(T("Einstellungen öffnen", "Open settings")) { openFullDiskAccess() }.buttonStyle(PButtonStyle(kind: .primary))
                    }
                }
            } else {
                FileListView(entries: state.trash, emptyText: T("Der Papierkorb ist leer.", "The Trash is empty."),
                             dateTitle: T("Zuletzt geändert", "Last modified"), showTagFilter: false, allowTrash: false)
            }
        }.padding(.horizontal, pageH).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await state.reloadTrash() }
    }
}

func openFullDiskAccess() {
    if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") { NSWorkspace.shared.open(u) }
}

// MARK: Duplikate

struct DuplicatesView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.pal) var pal

    var body: some View {
        let all = state.dups.flatMap(\.files)
        let wasted = state.dups.reduce(Int64(0)) { $0 + $1.wasted }
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: Section.duplicates.title,
                       lead: T("Identische Dateien (Inhalt per SHA-256 geprüft). Du kannst \(formatBytes(wasted)) sparen.", "Identical files (content verified via SHA-256). You can save \(formatBytes(wasted)).")) {
                Button(T("Automatisch markieren", "Auto-select")) {
                    var sel = Set<URL>()
                    for g in state.dups { for f in g.files.dropFirst() where !Safety.isProtected(f.url) { sel.insert(f.url) } }
                    state.selection = sel
                }.buttonStyle(PButtonStyle(kind: .primary)).disabled(state.dups.isEmpty)
                    .help(T("Behält je Gruppe die älteste Datei, markiert den Rest.", "Keeps the oldest file in each group and selects the rest."))
            }.padding(.top, 28).padding(.bottom, 14)
            if state.dups.isEmpty {
                Text(T("Keine Duplikate gefunden.", "No duplicates found.")).foregroundColor(pal.mut).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(state.dups.prefix(300)) { g in
                            VStack(spacing: 0) {
                                HStack {
                                    Text(T("\(g.files.count) Kopien · je \(formatBytes(g.each))", "\(g.files.count) copies · \(formatBytes(g.each)) each")).font(.mono(12, .semibold))
                                    Spacer()
                                    Text(T("verschwendet ", "wasted ") + formatBytes(g.wasted)).font(.mono(12)).foregroundColor(pal.warn)
                                }.padding(.horizontal, 10).padding(.vertical, 6).background(pal.paper2)
                                ForEach(g.files) { f in
                                    FileRow(entry: f, maxSize: g.each, selectable: true, showTag: false)
                                        .padding(.horizontal, 10)
                                    Line().opacity(0.5)
                                }
                            }.background(pal.card).overlay(Rectangle().stroke(pal.line, lineWidth: 1))
                        }
                    }
                }
            }
            SelectionBar(entries: all)
        }.padding(.horizontal, pageH).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: Deinstallieren

struct UninstallSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.pal) var pal
    let app: FileEntry
    @StateObject private var ui = UninstallUI()
    private var leftovers: [FileEntry] { get { ui.leftovers } nonmutating set { ui.leftovers = newValue } }
    private var picked: Set<URL> { get { ui.picked } nonmutating set { ui.picked = newValue } }
    private var loading: Bool { get { ui.loading } nonmutating set { ui.loading = newValue } }

    var body: some View {
        let all = [app] + leftovers
        let chosen = all.filter { picked.contains($0.url) }
        VStack(alignment: .leading, spacing: 12) {
            Text(T("„\(app.name)“ deinstallieren", "Uninstall “\(app.name)”")).font(.serif(20))
            Text(T("Die App und ihre Reste in ~/Library wandern in den Papierkorb.", "The app and its leftovers in ~/Library are moved to the Trash.")).foregroundColor(pal.mut)
            if loading { ProgressView().controlSize(.small) }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(all) { e in
                        HStack {
                            Button { if picked.contains(e.url) { picked.remove(e.url) } else { picked.insert(e.url) } } label: {
                                Check(on: picked.contains(e.url))
                            }.buttonStyle(.plain)
                            VStack(alignment: .leading) {
                                Text(e.name).font(.mono(13, .medium))
                                Text(FS.displayPath(e.url)).font(.system(size: 11)).foregroundColor(pal.mut)
                            }
                            Spacer()
                            Text(formatBytes(e.size)).font(.mono(13))
                        }.padding(.vertical, 5)
                        Line().opacity(0.5)
                    }
                }
            }.frame(height: 240)
            HStack {
                Text(formatBytes(chosen.reduce(0) { $0 + $1.size })).font(.mono(13, .semibold))
                Spacer()
                Button(T("Abbrechen", "Cancel")) { state.uninstallTarget = nil }.buttonStyle(PButtonStyle())
                Button(T("In den Papierkorb", "Move to Trash")) {
                    state.uninstallTarget = nil
                    state.performDelete(DeleteRequest(entries: chosen, permanent: false))
                }.buttonStyle(PButtonStyle(kind: .primary)).disabled(chosen.isEmpty)
            }
        }
        .padding(22).frame(width: 560).background(pal.paper).foregroundColor(pal.ink)
        .task {
            picked = [app.url]
            let l = await Task.detached { AppScanner.leftovers(for: app.url) }.value
            leftovers = l; picked.formUnion(l.map(\.url)); loading = false
        }
    }
}
