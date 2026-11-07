import Foundation
import CryptoKit

struct ScanConfig: Sendable {
    var roots: [URL]
    var downloads: URL
    var staleDays: Int
    var largeBytes: Int64
    var dupMinBytes: Int64
    var ignored: Set<String>
}

struct ScanResult: Sendable {
    var large: [FileEntry] = []
    var stale: [FileEntry] = []
    var downloads: [FileEntry] = []
    var dups: [DupGroup] = []
    var files = 0
    var bytes: Int64 = 0
    var errors = 0
}

enum FileScanner {
    static let docExts: Set<String> = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key", "txt", "rtf", "rtfd", "odt", "ods", "odp", "csv", "md", "epub", "tex", "pub"]

    static func run(_ cfg: ScanConfig, progress: @escaping @Sendable (Int, String) -> Void) -> ScanResult {
        var res = ScanResult()
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-Double(cfg.staleDays) * 86400)
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileSizeKey, .contentModificationDateKey, .contentAccessDateKey]
        let keySet = Set(keys)
        var buckets: [Int64: [FileEntry]] = [:]
        var staleCandidates: [FileEntry] = []
        var count = 0
        var errors = 0
        let dl = cfg.downloads.path + "/"

        // Überlappende Wurzeln entfernen
        let paths = Set(cfg.roots.map { $0.standardizedFileURL.path })
        let roots = cfg.roots.filter { r in
            var p = (r.standardizedFileURL.path as NSString).deletingLastPathComponent
            while p != "/" && !p.isEmpty { if paths.contains(p) { return false }; p = (p as NSString).deletingLastPathComponent }
            return true
        }

        for root in roots {
            if Task.isCancelled { break }
            guard let en = fm.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles], errorHandler: { _, _ in errors += 1; return true }) else { continue }
            while let u = en.nextObject() as? URL {
                if Task.isCancelled { break }
                if cfg.ignored.contains(u.path) { en.skipDescendants(); continue }
                guard let rv = try? u.resourceValues(forKeys: keySet) else { continue }
                if rv.isSymbolicLink == true { continue }
                let isDir = rv.isDirectory == true
                let blob = rv.isPackage == true || u.lastPathComponent == "node_modules"
                if isDir && !blob { continue }
                let size: Int64
                if isDir { en.skipDescendants(); size = FS.dirSize(u) } else { size = FS.fileSize(rv) }
                count += 1
                res.bytes += size
                if count % 300 == 0 { progress(count, u.path) }
                let touched = max(rv.contentModificationDate ?? .distantPast, rv.contentAccessDate ?? .distantPast)
                let e = FileEntry(url: u, size: size, date: touched, isDir: isDir, tag: nil)
                if size >= cfg.largeBytes { res.large.append(e) }
                if u.path.hasPrefix(dl) { res.downloads.append(e) }
                if docExts.contains(u.pathExtension.lowercased()) && touched < cutoff { staleCandidates.append(e) }
                if !isDir && size >= cfg.dupMinBytes { buckets[Int64(rv.fileSize ?? Int(size)), default: []].append(e) }
            }
        }

        progress(count, T("Dokumente prüfen …", "Checking documents …"))
        for var e in staleCandidates {
            if Task.isCancelled { break }
            if let used = FS.lastUsed(e.url) {
                if used > cutoff { continue }
                e.date = max(e.date ?? .distantPast, used)
            }
            res.stale.append(e)
        }

        res.dups = findDuplicates(buckets, progress: progress)
        res.files = count
        res.errors = errors
        return res
    }

    static func findDuplicates(_ buckets: [Int64: [FileEntry]], progress: @escaping @Sendable (Int, String) -> Void) -> [DupGroup] {
        var groups: [DupGroup] = []
        let candidates = buckets.values.filter { $0.count > 1 }
        var i = 0
        for bucket in candidates {
            if Task.isCancelled { break }
            i += 1
            progress(i, T("Duplikate vergleichen \(i)/\(candidates.count)", "Comparing duplicates \(i)/\(candidates.count)"))
            var byPartial: [String: [FileEntry]] = [:]
            for e in bucket { if let h = hash(e.url, limit: 65536) { byPartial[h, default: []].append(e) } }
            for b2 in byPartial.values where b2.count > 1 {
                var byFull: [String: [FileEntry]] = [:]
                for e in b2 { if let h = hash(e.url, limit: nil) { byFull[h, default: []].append(e) } }
                for b3 in byFull.values where b3.count > 1 {
                    let sorted = b3.sorted { ($0.date ?? .distantFuture, $0.url.path.count) < ($1.date ?? .distantFuture, $1.url.path.count) }
                    groups.append(DupGroup(files: sorted))
                }
            }
        }
        return groups.sorted { $0.wasted > $1.wasted }
    }

    static func hash(_ url: URL, limit: Int?) -> String? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        var hasher = SHA256()
        var remaining = limit ?? Int.max
        while remaining > 0 {
            if Task.isCancelled { return nil }
            guard let d = try? h.read(upToCount: min(1 << 20, remaining)), !d.isEmpty else { break }
            hasher.update(data: d)
            remaining -= d.count
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

enum CacheScanner {
    static func scan() -> [FileEntry] {
        let fm = FileManager.default
        let h = FS.home, lib = FS.library
        var items: [(URL, String)] = []

        func children(_ dir: URL, _ tag: String) {
            guard let c = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: []) else { return }
            for u in c where u.lastPathComponent != ".DS_Store" { items.append((u, tag)) }
        }
        func single(_ u: URL, _ tag: String) { if fm.fileExists(atPath: u.path) { items.append((u, tag)) } }

        children(lib.appendingPathComponent("Caches"), "cache")
        children(lib.appendingPathComponent("Logs"), "log")
        children(lib.appendingPathComponent("Developer/Xcode/DerivedData"), "xcode")
        children(lib.appendingPathComponent("Developer/Xcode/iOS DeviceSupport"), "xcode")
        children(lib.appendingPathComponent("Developer/Xcode/Archives"), "xcode")
        single(lib.appendingPathComponent("Developer/CoreSimulator/Caches"), "xcode")
        children(lib.appendingPathComponent("Application Support/MobileSync/Backup"), "backup")
        single(lib.appendingPathComponent("Containers/com.apple.mail/Data/Library/Mail Downloads"), "mail")
        single(h.appendingPathComponent(".npm/_cacache"), "dev")
        children(h.appendingPathComponent(".cache"), "dev")
        single(h.appendingPathComponent(".gradle/caches"), "dev")
        single(h.appendingPathComponent(".cargo/registry"), "dev")
        single(h.appendingPathComponent(".m2/repository"), "dev")

        let out = Box([FileEntry?](repeating: nil, count: items.count))
        DispatchQueue.concurrentPerform(iterations: items.count) { i in
            let (u, tag) = items[i]
            let size = FS.dirSize(u)
            guard size > 0 else { return }
            let isDir = (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let e = FileEntry(url: u, size: size, date: FS.modified(u), isDir: isDir, tag: tag)
            out.with { $0[i] = e }
        }
        return out.with { $0 }.compactMap { $0 }.sorted { $0.size > $1.size }
    }
}

enum AppScanner {
    static func scan() -> [FileEntry] {
        let fm = FileManager.default
        var apps: [URL] = []
        for dir in [URL(fileURLWithPath: "/Applications"), FS.home.appendingPathComponent("Applications")] {
            guard let c = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for u in c {
                if u.pathExtension == "app" { apps.append(u) }
                else if let sub = try? fm.contentsOfDirectory(at: u, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    apps += sub.filter { $0.pathExtension == "app" }
                }
            }
        }
        let out = Box([FileEntry?](repeating: nil, count: apps.count))
        DispatchQueue.concurrentPerform(iterations: apps.count) { i in
            let u = apps[i]
            let version = Bundle(url: u)?.infoDictionary?["CFBundleShortVersionString"] as? String
            let e = FileEntry(url: u, size: FS.dirSize(u), date: FS.lastUsed(u), isDir: true, tag: version.map { "v" + $0 })
            out.with { $0[i] = e }
        }
        return out.with { $0 }.compactMap { $0 }.sorted { $0.size > $1.size }
    }

    /// Reste einer App in ~/Library (Einstellungen, Caches, Container …).
    static func leftovers(for app: URL) -> [FileEntry] {
        guard let id = Bundle(url: app)?.bundleIdentifier else { return [] }
        let name = app.deletingPathExtension().lastPathComponent
        let lib = FS.library
        let fm = FileManager.default
        var cands: [URL] = [
            "Application Support/\(id)", "Application Support/\(name)", "Caches/\(id)", "Preferences/\(id).plist",
            "Containers/\(id)", "Saved Application State/\(id).savedState", "Logs/\(name)", "HTTPStorages/\(id)",
            "WebKit/\(id)", "Cookies/\(id).binarycookies", "Application Scripts/\(id)", "LaunchAgents/\(id).plist",
        ].map { lib.appendingPathComponent($0) }
        if let groups = try? fm.contentsOfDirectory(at: lib.appendingPathComponent("Group Containers"), includingPropertiesForKeys: nil) {
            cands += groups.filter { $0.lastPathComponent.contains(id) }
        }
        return cands.filter { fm.fileExists(atPath: $0.path) }.map {
            FileEntry(url: $0, size: FS.dirSize($0), date: FS.modified($0), isDir: true, tag: nil)
        }
    }
}

enum TrashScanner {
    static var url: URL { FS.home.appendingPathComponent(".Trash") }

    /// (Einträge, Zugriff verweigert?)
    static func items() -> ([FileEntry], Bool) {
        let fm = FileManager.default
        do {
            let c = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [])
            let list = c.filter { $0.lastPathComponent != ".DS_Store" }.map { u -> FileEntry in
                let isDir = (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                return FileEntry(url: u, size: FS.dirSize(u), date: FS.modified(u), isDir: isDir, tag: nil)
            }
            return (list.sorted { $0.size > $1.size }, false)
        } catch {
            return ([], true)
        }
    }
}
