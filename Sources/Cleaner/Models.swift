import Foundation

struct FileEntry: Identifiable, Hashable, Sendable {
    let url: URL
    var size: Int64
    var date: Date?
    var isDir: Bool
    var tag: String?
    var id: URL { url }
    var name: String { url.lastPathComponent }
}

struct DupGroup: Identifiable, Sendable {
    let id = UUID()
    var files: [FileEntry]
    var each: Int64 { files.map(\.size).max() ?? 0 }
    var wasted: Int64 { each * Int64(max(0, files.count - 1)) }
}

struct HistoryEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var count: Int
    var bytes: Int64
    var permanent: Bool
    var sample: String
}

struct DeleteRequest: Identifiable {
    let id = UUID()
    let entries: [FileEntry]
    let permanent: Bool
    var warning: String? = nil
    var totalSize: Int64 { entries.reduce(0) { $0 + $1.size } }
}

enum Section: String, CaseIterable, Identifiable {
    case overview, large, stale, downloads, duplicates, caches, apps, explorer, trash, settings
    var id: String { rawValue }
    static var nav: [Section] { allCases.filter { $0 != .settings } }
    var title: String {
        switch self {
        case .overview: return T("Übersicht", "Overview")
        case .large: return T("Große Dateien", "Large files")
        case .stale: return T("Veraltete Dokumente", "Outdated documents")
        case .downloads: return T("Downloads", "Downloads")
        case .duplicates: return T("Duplikate", "Duplicates")
        case .caches: return T("Caches & Logs", "Caches & logs")
        case .apps: return T("Apps", "Apps")
        case .explorer: return T("Explorer", "Explorer")
        case .trash: return T("Papierkorb", "Trash")
        case .settings: return T("Einstellungen", "Settings")
        }
    }
}

func tagLabel(_ key: String) -> String {
    switch key {
    case "cache": return "Cache"
    case "log": return T("Protokoll", "Log")
    case "xcode": return "Xcode"
    case "dev": return T("Entwickler", "Developer")
    case "backup": return T("iOS-Backup", "iOS backup")
    case "mail": return "Mail"
    default: return key
    }
}
