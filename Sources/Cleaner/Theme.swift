import SwiftUI
import Foundation

extension Color {
    init(hex: String) {
        var v: UInt64 = 0
        Foundation.Scanner(string: hex).scanHexInt64(&v)
        self.init(.sRGB, red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255, opacity: 1)
    }
}

struct Palette: Equatable {
    let paper, paper2, card, ink, mut, line, acc, accfg, side, sidefg, sidemut, sidehover, warn, bad, ok: Color
    let dark: Bool

    /// Reihenfolge wie in HomebrUI: paper paper2 card ink mut line acc accfg side sidefg sidemut sidehover warn bad ok
    init(_ s: String, dark: Bool) {
        let c = s.split(separator: " ").map { Color(hex: String($0)) }
        paper = c[0]; paper2 = c[1]; card = c[2]; ink = c[3]; mut = c[4]; line = c[5]; acc = c[6]; accfg = c[7]
        side = c[8]; sidefg = c[9]; sidemut = c[10]; sidehover = c[11]; warn = c[12]; bad = c[13]; ok = c[14]
        self.dark = dark
    }
}

struct ThemeInfo: Identifiable {
    let id: String
    let de: String
    let en: String
    let palette: Palette
    var name: String { T(de, en) }
}

enum Theme {
    static let defaultLight = Palette("f1ebdd e8e0cf f8f4e9 1d1b17 6f685a cfc6b2 b85c10 ffffff 201d18 e9e1cf 8f8573 2a2620 9a4a00 a8281c 2d6a3a", dark: false)
    static let defaultDark = Palette("171510 201d16 1c1a14 eee6d3 9b927f 3a352a e8923a 1d1308 0f0e0b e9e1cf 8f8573 2a2620 f0b068 ff8a78 7fcf94", dark: true)

    static let all: [ThemeInfo] = [
        ThemeInfo(id: "auto", de: "Standard (folgt dem System)", en: "Default (follows system)", palette: defaultLight),
        ThemeInfo(id: "light", de: "Standard hell", en: "Default light", palette: defaultLight),
        ThemeInfo(id: "dark", de: "Standard dunkel", en: "Default dark", palette: defaultDark),
        ThemeInfo(id: "solarized-light", de: "Solarized Light", en: "Solarized Light", palette: Palette("fdf6e3 eee8d5 f7f0dc 073642 657b83 d9d2bd cb4b16 ffffff 073642 eee8d5 93a1a1 0d4a5a b58900 dc322f 6c7a00", dark: false)),
        ThemeInfo(id: "solarized-dark", de: "Solarized Dark", en: "Solarized Dark", palette: Palette("002b36 073642 04323d eee8d5 93a1a1 11505e cb4b16 ffffff 00212b eee8d5 839496 073642 d3a017 ff5f57 a3b800", dark: true)),
        ThemeInfo(id: "gruvbox-light", de: "Gruvbox Light", en: "Gruvbox Light", palette: Palette("fbf1c7 ebdbb2 f9f5d7 3c3836 7c6f64 d5c4a1 d65d0e ffffff 3c3836 fbf1c7 a89984 504945 b57614 cc241d 79740e", dark: false)),
        ThemeInfo(id: "gruvbox-dark", de: "Gruvbox Dark", en: "Gruvbox Dark", palette: Palette("282828 32302f 2b2a28 ebdbb2 a89984 504945 fe8019 1d2021 1d2021 ebdbb2 928374 32302f fabd2f fb4934 b8bb26", dark: true)),
        ThemeInfo(id: "nord", de: "Nord", en: "Nord", palette: Palette("2e3440 3b4252 353c4a eceff4 a3adbf 4c566a 88c0d0 1f2430 252a33 eceff4 8a94a8 3b4252 ebcb8b d57780 a3be8c", dark: true)),
        ThemeInfo(id: "dracula", de: "Dracula", en: "Dracula", palette: Palette("282a36 343746 2f3140 f8f8f2 9aa0c3 44475a bd93f9 1d1e28 21222c f8f8f2 8a90b8 343746 ffb86c ff5555 50fa7b", dark: true)),
        ThemeInfo(id: "monokai", de: "Monokai", en: "Monokai", palette: Palette("272822 33342d 2d2e27 f8f8f2 a09e8a 49483e a6e22e 1b1c17 1e1f1a f8f8f2 8f8d7c 33342d e6db74 f92672 a6e22e", dark: true)),
        ThemeInfo(id: "tokyo-night", de: "Tokyo Night", en: "Tokyo Night", palette: Palette("1a1b26 24283b 1f2335 c0caf5 8b93b9 33384f 7aa2f7 14151f 16161e c0caf5 7f88b0 24283b e0af68 f7768e 9ece6a", dark: true)),
        ThemeInfo(id: "one-dark", de: "One Dark", en: "One Dark", palette: Palette("282c34 2f343e 2c313a dcdfe4 9aa1ae 3e4451 61afef 1b1e24 21252b dcdfe4 8a919d 2f343e e5c07b e06c75 98c379", dark: true)),
        ThemeInfo(id: "catppuccin-latte", de: "Catppuccin Latte", en: "Catppuccin Latte", palette: Palette("eff1f5 e6e9ef f6f7fa 4c4f69 6c6f85 ccd0da 8839ef ffffff 4c4f69 eff1f5 acb0be 5c5f77 df8e1d d20f39 40a02b", dark: false)),
        ThemeInfo(id: "catppuccin-mocha", de: "Catppuccin Mocha", en: "Catppuccin Mocha", palette: Palette("1e1e2e 313244 262637 cdd6f4 a6adc8 45475a cba6f7 1e1e2e 11111b cdd6f4 9399b2 313244 f9e2af f38ba8 a6e3a1", dark: true)),
    ]
}

private struct PalKey: EnvironmentKey { static let defaultValue = Theme.defaultLight }
extension EnvironmentValues {
    var pal: Palette {
        get { self[PalKey.self] }
        set { self[PalKey.self] = newValue }
    }
}

extension Font {
    static func mono(_ s: CGFloat, _ w: Font.Weight = .regular) -> Font { .system(size: s, weight: w, design: .monospaced) }
    static func serif(_ s: CGFloat, _ w: Font.Weight = .semibold) -> Font { .system(size: s, weight: w, design: .serif) }
}
