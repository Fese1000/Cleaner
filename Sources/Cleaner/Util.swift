import Foundation
import AppKit
import CoreServices
import UniformTypeIdentifiers

/// Übersetzung: erst Deutsch, dann Englisch.
func T(_ de: String, _ en: String) -> String { Settings.shared.lang == .de ? de : en }

private let byteFormatter: ByteCountFormatter = {
    let f = ByteCountFormatter()
    f.countStyle = .file
    f.allowsNonnumericFormatting = false
    return f
}()

func formatBytes(_ b: Int64) -> String { byteFormatter.string(fromByteCount: b) }

final class CancelToken: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    func cancel() { lock.lock(); flag = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return flag }
}

final class Box<V>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: V
    init(_ v: V) { value = v }
    func with<R>(_ f: (inout V) -> R) -> R { lock.lock(); defer { lock.unlock() }; return f(&value) }
}

enum FS {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static var library: URL { home.appendingPathComponent("Library") }

    static func fileSize(_ rv: URLResourceValues) -> Int64 {
        Int64(rv.totalFileAllocatedSize ?? rv.fileSize ?? 0)
    }

    /// Belegter Platz eines Ordners (oder einer Datei), rekursiv.
    static func dirSize(_ url: URL, cancel: CancelToken? = nil) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey, .isDirectoryKey]
        if let rv = try? url.resourceValues(forKeys: Set(keys)), rv.isDirectory != true {
            return fileSize(rv)
        }
        guard let en = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [], errorHandler: { _, _ in true }) else { return 0 }
        var total: Int64 = 0
        var n = 0
        while let u = en.nextObject() as? URL {
            n += 1
            if n % 256 == 0, (cancel?.isCancelled ?? false) || Task.isCancelled { break }
            if let rv = try? u.resourceValues(forKeys: Set(keys)), rv.isRegularFile == true {
                total += fileSize(rv)
            }
        }
        return total
    }

    static func lastUsed(_ url: URL) -> Date? {
        guard let item = MDItemCreateWithURL(nil, url as CFURL) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }

    static func modified(_ url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    static func displayPath(_ url: URL) -> String {
        (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
    }

    static func reveal(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    static func open(_ url: URL) { NSWorkspace.shared.open(url) }

    static func quickLook(_ url: URL) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
        p.arguments = ["-p", url.path]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
    }
}

/// Schutz vor versehentlichem Löschen wichtiger Ordner.
enum Safety {
    static func isProtected(_ url: URL) -> Bool {
        let p = url.standardizedFileURL.path
        let h = FS.home.path
        if p == "/" || p == h { return true }
        if p == Bundle.main.bundlePath { return true }
        let ext = url.pathExtension.lowercased()
        if ["photoslibrary", "musiclibrary", "tvlibrary", "imovielibrary"].contains(ext) { return true }
        guard p.hasPrefix(h + "/") || p.hasPrefix("/Applications/") || p.hasPrefix("/Volumes/") else { return true }
        if p.hasPrefix(h + "/") {
            let rel = p.dropFirst(h.count + 1).split(separator: "/").map(String.init)
            if rel.count == 1 {
                if rel[0].hasPrefix(".") { return true }
                if ["Documents", "Desktop", "Downloads", "Library", "Movies", "Music", "Pictures", "Public", "Applications"].contains(rel[0]) { return true }
            }
            if rel.count == 2, rel[0] == "Library" { return true }
        }
        return false
    }
}

enum Deleter {
    struct Outcome { var deleted: [URL] = []; var failed: [(URL, String)] = [] }

    static func delete(_ urls: [URL], permanent: Bool) -> Outcome {
        let fm = FileManager.default
        var out = Outcome()
        let paths = Set(urls.map { $0.standardizedFileURL.path })
        // Liegt ein übergeordneter Ordner ebenfalls in der Auswahl, reicht er allein.
        let top = urls.filter { u in
            var parent = u.standardizedFileURL.deletingLastPathComponent().path
            while parent != "/" && !parent.isEmpty {
                if paths.contains(parent) { return false }
                parent = (parent as NSString).deletingLastPathComponent
            }
            return true
        }
        for u in top {
            if Safety.isProtected(u) {
                out.failed.append((u, T("Geschützt", "Protected")))
                continue
            }
            do {
                if permanent { try fm.removeItem(at: u) } else { try fm.trashItem(at: u, resultingItemURL: nil) }
                out.deleted.append(u)
            } catch {
                out.failed.append((u, error.localizedDescription))
            }
        }
        return out
    }
}

enum IconCache {
    private static let cache = NSCache<NSString, NSImage>()
    static func icon(for e: FileEntry) -> NSImage {
        let ext = e.url.pathExtension.lowercased()
        let perPath = e.isDir || ext == "app"
        let key = (perPath ? e.url.path : "ext:" + ext) as NSString
        if let i = cache.object(forKey: key) { return i }
        let img: NSImage
        if perPath { img = NSWorkspace.shared.icon(forFile: e.url.path) }
        else if let t = UTType(filenameExtension: ext) { img = NSWorkspace.shared.icon(for: t) }
        else { img = NSWorkspace.shared.icon(for: .data) }
        cache.setObject(img, forKey: key)
        return img
    }
}

enum Fmt {
    private static let rel: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .full; return f
    }()
    static func age(_ d: Date?) -> String {
        guard let d else { return "–" }
        rel.locale = Locale(identifier: Settings.shared.lang.rawValue)
        return rel.localizedString(for: d, relativeTo: Date())
    }
}
