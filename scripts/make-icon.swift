// Zeichnet das App-Icon (Donut = Speicherbelegung) und schreibt assets/AppIcon.icns.
// Aufruf: swiftc scripts/make-icon.swift -o /tmp/mkicon && /tmp/mkicon assets
import AppKit

func hex(_ s: String) -> NSColor {
    var v: UInt64 = 0; Scanner(string: s).scanHexInt64(&v)
    return NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
}

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let box = NSRect(x: s * 0.098, y: s * 0.098, width: s * 0.804, height: s * 0.804)
    hex("201d18").setFill()
    NSBezierPath(roundedRect: box, xRadius: s * 0.18, yRadius: s * 0.18).fill()
    let c = NSPoint(x: s / 2, y: s / 2), r = s * 0.27, w = s * 0.12
    let track = NSBezierPath(); track.appendArc(withCenter: c, radius: r, startAngle: 0, endAngle: 360)
    track.lineWidth = w; hex("3a352a").setStroke(); track.stroke()
    let arc = NSBezierPath(); arc.appendArc(withCenter: c, radius: r, startAngle: 90, endAngle: 90 - 360 * 0.72, clockwise: true)
    arc.lineWidth = w; arc.lineCapStyle = .butt; hex("e8923a").setStroke(); arc.stroke()
    hex("f1ebdd").setFill()
    NSBezierPath(ovalIn: NSRect(x: c.x - s * 0.045, y: c.y - s * 0.045, width: s * 0.09, height: s * 0.09)).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let set = out + "/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: set)
try! FileManager.default.createDirectory(atPath: set, withIntermediateDirectories: true)
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try! render(px).write(to: URL(fileURLWithPath: "\(set)/icon_\(name).png"))
}
let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", set, "-o", out + "/AppIcon.icns"]; try! p.run(); p.waitUntilExit()
try? FileManager.default.removeItem(atPath: set)
