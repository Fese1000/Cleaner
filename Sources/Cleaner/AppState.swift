import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var section: Section = .overview { didSet { selection.removeAll() } }
    @Published var selection = Set<URL>()

    @Published var scanning = false
    @Published var scanProgress = ""
    @Published var scanCount = 0
    @Published var lastScan: Date?
    @Published var permissionIssues = false
    @Published var scannedBytes: Int64 = 0

    @Published var large: [FileEntry] = []
    @Published var stale: [FileEntry] = []
    @Published var downloads: [FileEntry] = []
    @Published var dups: [DupGroup] = []
    @Published var caches: [FileEntry] = []
    @Published var apps: [FileEntry] = []
    @Published var trash: [FileEntry] = []
    @Published var trashDenied = false

    @Published var diskTotal: Int64 = 0
    @Published var diskFree: Int64 = 0

    @Published var confirm: DeleteRequest?
    @Published var uninstallTarget: FileEntry?
    @Published var toast: String?
    @Published var busy = false

    let settings = Settings.shared
    private var scanTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    init() {
        refreshDisk()
        if let n = ProcessInfo.processInfo.environment["CLEANER_SECTION"], let sec = Section(rawValue: n) { section = sec }
    }

    // MARK: Scan

    func startScan() {
        guard !scanning else { return }
        scanning = true
        scanCount = 0
        scanProgress = T("Dateien durchsuchen …", "Scanning files …")
        refreshDisk()
        let cfg = ScanConfig(
            roots: settings.roots.map { URL(fileURLWithPath: $0) },
            downloads: FS.home.appendingPathComponent("Downloads"),
            staleDays: settings.staleDays,
            largeBytes: Int64(settings.largeMB) * 1_000_000,
            dupMinBytes: Int64(settings.dupMinMB) * 1_000_000,
            ignored: Set(settings.ignored))
        scanTask = Task { [weak self] in
            let h = Task.detached(priority: .userInitiated) { () -> ScanResult in
                FileScanner.run(cfg) { count, path in
                    Task { @MainActor in self?.scanCount = count; self?.scanProgress = path }
                }
            }
            let r = await withTaskCancellationHandler { await h.value } onCancel: { h.cancel() }
            guard let self else { return }
            if !Task.isCancelled {
                self.large = r.large; self.stale = r.stale; self.downloads = r.downloads; self.dups = r.dups
                self.scannedBytes = r.bytes
                self.permissionIssues = r.errors > 20
                self.scanProgress = T("Caches prüfen …", "Checking caches …")
                self.caches = await Task.detached { CacheScanner.scan() }.value
                self.scanProgress = T("Apps prüfen …", "Checking apps …")
                self.apps = await Task.detached { AppScanner.scan() }.value
                await self.reloadTrash()
                self.lastScan = Date()
            }
            self.scanning = false
            self.scanProgress = ""
        }
    }

    func cancelScan() { scanTask?.cancel() }

    func refreshDisk() {
        let url = URL(fileURLWithPath: "/")
        if let v = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) {
            diskTotal = Int64(v.volumeTotalCapacity ?? 0)
            diskFree = v.volumeAvailableCapacityForImportantUsage ?? 0
        }
    }

    func reloadTrash() async {
        let (items, denied) = await Task.detached { TrashScanner.items() }.value
        trash = items
        trashDenied = denied
    }

    func badge(_ s: Section) -> String? {
        let n: Int
        switch s {
        case .large: n = large.count
        case .stale: n = stale.count
        case .downloads: n = downloads.count
        case .duplicates: n = dups.count
        case .caches: n = caches.count
        case .apps: n = apps.count
        case .trash: n = trash.count
        default: n = 0
        }
        return n > 0 ? n.formatted() : nil
    }

    // MARK: Auswahl

    func toggle(_ url: URL) {
        if selection.contains(url) { selection.remove(url) } else { selection.insert(url) }
    }

    // MARK: Löschen

    func requestDelete(_ entries: [FileEntry], permanent: Bool) {
        guard !entries.isEmpty else { return }
        var warning: String?
        let sel = Set(entries.map(\.url))
        let full = dups.filter { g in g.files.allSatisfy { sel.contains($0.url) } }.count
        if full > 0 {
            warning = T("In \(full) Duplikat-Gruppe(n) sind ALLE Kopien ausgewählt – danach existiert keine Kopie mehr.",
                        "ALL copies are selected in \(full) duplicate group(s) – no copy would remain.")
        }
        confirm = DeleteRequest(entries: entries, permanent: permanent, warning: warning)
    }

    func performDelete(_ req: DeleteRequest) {
        guard !busy else { return }
        busy = true
        let urls = req.entries.map(\.url)
        let sizes = Dictionary(req.entries.map { ($0.url.standardizedFileURL.path, $0.size) }, uniquingKeysWith: { a, _ in a })
        Task {
            let out = await Task.detached { Deleter.delete(urls, permanent: req.permanent) }.value
            var bytes: Int64 = 0
            for u in out.deleted { bytes += sizes[u.standardizedFileURL.path] ?? 0 }
            prune(out.deleted)
            selection.subtract(out.deleted)
            if !out.deleted.isEmpty {
                settings.history.insert(HistoryEntry(date: Date(), count: out.deleted.count, bytes: bytes, permanent: req.permanent,
                                                     sample: out.deleted.first?.lastPathComponent ?? ""), at: 0)
                if req.permanent { settings.totalFreed += bytes }
            }
            await reloadTrash()
            refreshDisk()
            busy = false
            if out.failed.isEmpty {
                show(req.permanent
                     ? T("\(formatBytes(bytes)) endgültig gelöscht.", "\(formatBytes(bytes)) deleted permanently.")
                     : T("\(formatBytes(bytes)) in den Papierkorb verschoben – frei wird der Platz nach dem Leeren.", "\(formatBytes(bytes)) moved to Trash – space is freed once it is emptied."))
            } else {
                show(T("\(out.failed.count) Element(e) konnten nicht gelöscht werden: ", "\(out.failed.count) item(s) could not be deleted: ") + (out.failed.first?.1 ?? ""))
            }
        }
    }

    func emptyTrash() {
        guard !busy else { return }
        busy = true
        let items = trash
        Task {
            let out = await Task.detached { Deleter.delete(items.map(\.url), permanent: true) }.value
            let bytes = items.filter { i in out.deleted.contains { $0.path == i.url.path } }.reduce(Int64(0)) { $0 + $1.size }
            if bytes > 0 {
                settings.totalFreed += bytes
                settings.history.insert(HistoryEntry(date: Date(), count: out.deleted.count, bytes: bytes, permanent: true, sample: T("Papierkorb geleert", "Trash emptied")), at: 0)
            }
            await reloadTrash()
            refreshDisk()
            busy = false
            show(out.failed.isEmpty ? T("Papierkorb geleert (\(formatBytes(bytes))).", "Trash emptied (\(formatBytes(bytes))).")
                                    : T("Einige Elemente konnten nicht entfernt werden.", "Some items could not be removed."))
        }
    }

    func ignore(_ url: URL) {
        if !settings.ignored.contains(url.path) { settings.ignored.append(url.path) }
        prune([url])
    }

    private func prune(_ urls: [URL]) {
        let paths = urls.map { $0.standardizedFileURL.path }
        func gone(_ e: FileEntry) -> Bool {
            let p = e.url.standardizedFileURL.path
            return paths.contains { p == $0 || p.hasPrefix($0 + "/") }
        }
        large.removeAll(where: gone); stale.removeAll(where: gone); downloads.removeAll(where: gone)
        caches.removeAll(where: gone); apps.removeAll(where: gone)
        dups = dups.map { var g = $0; g.files.removeAll(where: gone); return g }.filter { $0.files.count > 1 }
    }

    func show(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled { toast = nil }
        }
    }
}
