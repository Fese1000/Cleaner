import SwiftUI

enum Lang: String, CaseIterable, Identifiable {
    case de, en
    var id: String { rawValue }
    var label: String { self == .de ? "Deutsch" : "English" }
}

enum DeleteMode: String, CaseIterable, Identifiable {
    case trash, permanent
    var id: String { rawValue }
}

final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard

    @Published var lang: Lang { didSet { d.set(lang.rawValue, forKey: "lang") } }
    @Published var themeID: String { didSet { d.set(themeID, forKey: "theme") } }
    @Published var staleDays: Int { didSet { d.set(staleDays, forKey: "staleDays") } }
    @Published var largeMB: Int { didSet { d.set(largeMB, forKey: "largeMB") } }
    @Published var dupMinMB: Int { didSet { d.set(dupMinMB, forKey: "dupMinMB") } }
    @Published var roots: [String] { didSet { d.set(roots, forKey: "roots") } }
    @Published var ignored: [String] { didSet { d.set(ignored, forKey: "ignored") } }
    @Published var deleteMode: DeleteMode { didSet { d.set(deleteMode.rawValue, forKey: "deleteMode") } }
    @Published var autoCheckUpdates: Bool { didSet { d.set(autoCheckUpdates, forKey: "autoCheck") } }
    @Published var totalFreed: Int64 { didSet { d.set(totalFreed, forKey: "totalFreed") } }
    @Published var history: [HistoryEntry] { didSet { saveHistory() } }

    init() {
        let pref = Locale.preferredLanguages.first ?? "en"
        lang = Lang(rawValue: d.string(forKey: "lang") ?? (pref.hasPrefix("de") ? "de" : "en")) ?? .en
        themeID = d.string(forKey: "theme") ?? "auto"
        staleDays = d.object(forKey: "staleDays") as? Int ?? 365
        largeMB = d.object(forKey: "largeMB") as? Int ?? 100
        dupMinMB = d.object(forKey: "dupMinMB") as? Int ?? 5
        roots = d.stringArray(forKey: "roots") ?? Settings.defaultRoots()
        ignored = d.stringArray(forKey: "ignored") ?? []
        deleteMode = DeleteMode(rawValue: d.string(forKey: "deleteMode") ?? "trash") ?? .trash
        autoCheckUpdates = d.bool(forKey: "autoCheck")
        totalFreed = Int64(d.integer(forKey: "totalFreed"))
        if let data = d.data(forKey: "history"), let h = try? JSONDecoder().decode([HistoryEntry].self, from: data) { history = h } else { history = [] }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(Array(history.prefix(200))) { d.set(data, forKey: "history") }
    }

    static func defaultRoots() -> [String] {
        let skip: Set<String> = ["Library", "Applications", "Public"]
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(at: FS.home, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        return items.filter { ((try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false) && !skip.contains($0.lastPathComponent) }
            .map(\.path).sorted()
    }

    var theme: ThemeInfo { Theme.all.first { $0.id == themeID } ?? Theme.all[0] }

    func palette(system: ColorScheme) -> Palette {
        if themeID == "auto" { return system == .dark ? Theme.defaultDark : Theme.defaultLight }
        return theme.palette
    }

    var forcedScheme: ColorScheme? {
        themeID == "auto" ? nil : (theme.palette.dark ? .dark : .light)
    }
}
