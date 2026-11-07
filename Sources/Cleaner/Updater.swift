import Foundation
import CryptoKit
import AppKit

/// Selbst-Update über GitHub-Releases (wie HomebrUI): DMG laden, Prüfsumme + Signatur prüfen, App ersetzen, neu starten.
@MainActor
final class Updater: ObservableObject {
    static let repo = "Fese1000/Cleaner"
    nonisolated static let bundleID = "de.felix.cleaner"

    enum Phase: Equatable {
        case idle, checking, upToDate
        case available(version: String)
        case downloading(Double)
        case installing
        case error(String)
    }

    @Published var phase: Phase = .idle
    private var asset: GHAsset?

    struct GHAsset: Decodable { let name: String; let browser_download_url: String; let size: Int64; let digest: String? }
    struct GHRelease: Decodable { let tag_name: String; let assets: [GHAsset] }

    static var current: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev" }
    static var assetName: String {
        #if arch(arm64)
        return "Cleaner-AppleSilicon.dmg"
        #else
        return "Cleaner-Intel.dmg"
        #endif
    }

    static func parse(_ v: String) -> [Int]? {
        let s = v.hasPrefix("v") ? String(v.dropFirst()) : v
        let parts = s.split(separator: ".").map { Int($0) }
        return parts.contains(where: { $0 == nil }) || parts.isEmpty ? nil : parts.compactMap { $0 }
    }

    var canInstall: Bool {
        let b = Bundle.main.bundleURL
        return b.pathExtension == "app" && FileManager.default.isWritableFile(atPath: b.path) && FileManager.default.isWritableFile(atPath: b.deletingLastPathComponent().path)
    }

    func check() {
        if case .checking = phase { return }
        phase = .checking
        Task {
            do {
                var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(Updater.repo)/releases/latest")!)
                req.setValue("Cleaner", forHTTPHeaderField: "User-Agent")
                req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                req.timeoutInterval = 10
                let (data, resp) = try await URLSession.shared.data(for: req)
                if (resp as? HTTPURLResponse)?.statusCode == 404 {
                    phase = .error(T("Noch keine veröffentlichte Version gefunden.", "No published release found yet.")); return
                }
                let rel = try JSONDecoder().decode(GHRelease.self, from: data)
                guard let latest = Updater.parse(rel.tag_name) else { throw URLError(.cannotParseResponse) }
                guard let cur = Updater.parse(Updater.current), latest.lexicographicallyPrecedes(cur) == false, latest != cur else {
                    phase = .upToDate; return
                }
                guard let a = rel.assets.first(where: { $0.name == Updater.assetName }) else {
                    phase = .error(T("Kein passendes DMG im Release.", "No matching DMG in the release.")); return
                }
                asset = a
                phase = .available(version: rel.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "v")))
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }

    func install() {
        guard case .available(let version) = phase, let a = asset else { return }
        guard a.browser_download_url.hasPrefix("https://github.com/\(Updater.repo)/releases/download/") else {
            phase = .error(T("Unerwartete Download-Adresse.", "Unexpected download URL.")); return
        }
        guard let digest = a.digest, digest.hasPrefix("sha256:") else {
            phase = .error(T("Prüfsumme fehlt – Update abgebrochen.", "Checksum missing – update aborted.")); return
        }
        guard canInstall else {
            phase = .error(T("Die App kann sich hier nicht selbst ersetzen (Schreibrechte oder kein .app-Bundle).", "The app cannot replace itself here (permissions or not an .app bundle).")); return
        }
        phase = .downloading(0)
        Task {
            do {
                let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("cleaner-update-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
                let dmg = tmp.appendingPathComponent("update.dmg")
                try await download(URL(string: a.browser_download_url)!, to: dmg, total: a.size)

                phase = .installing
                let expected = String(digest.dropFirst(7))
                let actual = try await Task.detached { try Updater.sha256(of: dmg) }.value
                guard actual == expected else { throw NSError(domain: "Updater", code: 1, userInfo: [NSLocalizedDescriptionKey: T("Prüfsumme stimmt nicht.", "Checksum mismatch.")]) }

                let newApp = try await Task.detached { try Updater.extract(dmg: dmg, into: tmp, version: version) }.value
                try Updater.launchReplacement(newApp: newApp, tmp: tmp)
                NSApp.terminate(nil)
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }

    private func download(_ url: URL, to file: URL, total: Int64) async throws {
        var req = URLRequest(url: url)
        req.setValue("Cleaner", forHTTPHeaderField: "User-Agent")
        let (bytes, _) = try await URLSession.shared.bytes(for: req)
        FileManager.default.createFile(atPath: file.path, contents: nil)
        let h = try FileHandle(forWritingTo: file)
        defer { try? h.close() }
        var buf = Data(); var got: Int64 = 0
        for try await b in bytes {
            buf.append(b); got += 1
            if buf.count >= 1 << 18 {
                try h.write(contentsOf: buf); buf.removeAll(keepingCapacity: true)
                if total > 0 { phase = .downloading(min(1, Double(got) / Double(total))) }
            }
        }
        try h.write(contentsOf: buf)
    }

    nonisolated static func sha256(of url: URL) throws -> String {
        let h = try FileHandle(forReadingFrom: url)
        defer { try? h.close() }
        var hasher = SHA256()
        while let d = try h.read(upToCount: 1 << 20), !d.isEmpty { hasher.update(data: d) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    @discardableResult
    nonisolated static func run(_ exe: String, _ args: [String]) -> (Int32, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe; p.standardError = pipe
        do { try p.run() } catch { return (-1, "\(error)") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }

    nonisolated static func extract(dmg: URL, into tmp: URL, version: String) throws -> URL {
        let mnt = tmp.appendingPathComponent("mnt")
        try FileManager.default.createDirectory(at: mnt, withIntermediateDirectories: true)
        let (code, out) = run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-noverify", "-mountpoint", mnt.path, dmg.path])
        guard code == 0 else { throw NSError(domain: "Updater", code: 2, userInfo: [NSLocalizedDescriptionKey: out]) }
        defer { run("/usr/bin/hdiutil", ["detach", "-quiet", mnt.path]) }
        let stage = tmp.appendingPathComponent("stage/Cleaner.app")
        try FileManager.default.createDirectory(at: stage.deletingLastPathComponent(), withIntermediateDirectories: true)
        let (c2, o2) = run("/usr/bin/ditto", [mnt.appendingPathComponent("Cleaner.app").path, stage.path])
        guard c2 == 0 else { throw NSError(domain: "Updater", code: 3, userInfo: [NSLocalizedDescriptionKey: o2]) }
        let (c3, o3) = run("/usr/bin/codesign", ["--verify", "--deep", "--strict", stage.path])
        guard c3 == 0 else { throw NSError(domain: "Updater", code: 4, userInfo: [NSLocalizedDescriptionKey: T("Signatur ungültig: ", "Invalid signature: ") + o3]) }
        let info = Bundle(url: stage)?.infoDictionary
        guard info?["CFBundleIdentifier"] as? String == bundleID, info?["CFBundleShortVersionString"] as? String == version else {
            throw NSError(domain: "Updater", code: 5, userInfo: [NSLocalizedDescriptionKey: T("Unerwartete App im Update.", "Unexpected app in update.")])
        }
        return stage
    }

    nonisolated static func launchReplacement(newApp: URL, tmp: URL) throws {
        let dest = Bundle.main.bundleURL.path
        let script = tmp.appendingPathComponent("replace.sh")
        let body = """
        #!/bin/bash
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.3; done
        rm -rf "\(dest)" && /usr/bin/ditto "\(newApp.path)" "\(dest)" && /usr/bin/xattr -dr com.apple.quarantine "\(dest)"
        /usr/bin/open "\(dest)"
        rm -rf "\(tmp.path)"
        """
        try body.write(to: script, atomically: true, encoding: .utf8)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [script.path]
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run()
    }
}
