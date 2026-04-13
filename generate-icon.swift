#!/usr/bin/env swift
//
// generate-icon.swift
//
// Draws a 1024x1024 PNG app icon for the ASCII Chart app:
//   - macOS-style rounded-square tile
//   - subtle dark-slate gradient background
//   - bold white "ASCII" wordmark in a monospaced font
//
// Writes icon-1024.png into the current working directory.
//
import AppKit
import CoreGraphics

let size: CGFloat = 1024

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 32
) else {
    fputs("Failed to allocate bitmap\n", stderr)
    exit(1)
}
bitmap.size = NSSize(width: size, height: size)

guard let ctx = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Failed to create graphics context\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

// 1) Rounded-square tile. ~22.37% corner radius matches the macOS squircle.
let tile = NSRect(x: 0, y: 0, width: size, height: size)
let cornerRadius: CGFloat = size * 0.2237
let tilePath = NSBezierPath(roundedRect: tile,
                            xRadius: cornerRadius,
                            yRadius: cornerRadius)
tilePath.addClip()

// 2) Dark-slate gradient background (terminal-ish).
let top = NSColor(srgbRed: 0.18, green: 0.24, blue: 0.38, alpha: 1.0)
let bottom = NSColor(srgbRed: 0.06, green: 0.08, blue: 0.14, alpha: 1.0)
if let gradient = NSGradient(starting: top, ending: bottom) {
    gradient.draw(in: tile, angle: -90)
}

// 3) A faint grid/hatch so the background has some texture.
NSColor(white: 1.0, alpha: 0.03).setStroke()
let hatch = NSBezierPath()
hatch.lineWidth = 2
let step: CGFloat = 48
var x: CGFloat = 0
while x <= size {
    hatch.move(to: NSPoint(x: x, y: 0))
    hatch.line(to: NSPoint(x: x, y: size))
    x += step
}
var y: CGFloat = 0
while y <= size {
    hatch.move(to: NSPoint(x: 0, y: y))
    hatch.line(to: NSPoint(x: size, y: y))
    y += step
}
hatch.stroke()

// 4) "ASCII" wordmark, centered.
let text = "ASCII"
let fontSize: CGFloat = 300
let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .black)

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center

let shadow = NSShadow()
shadow.shadowOffset = NSSize(width: 0, height: -6)
shadow.shadowBlurRadius = 14
shadow.shadowColor = NSColor(white: 0, alpha: 0.45)

let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white,
    .kern: -12.0,
    .paragraphStyle: paragraph,
    .shadow: shadow,
]
let attributed = NSAttributedString(string: text, attributes: attrs)
let textSize = attributed.size()
let textRect = NSRect(
    x: (size - textSize.width) / 2,
    y: (size - textSize.height) / 2 - size * 0.015,  // slight optical adjust
    width: textSize.width,
    height: textSize.height
)
attributed.draw(in: textRect)

// 5) Thin inner highlight along the top to add a little depth.
let highlightPath = NSBezierPath(roundedRect: tile.insetBy(dx: 6, dy: 6),
                                 xRadius: cornerRadius - 6,
                                 yRadius: cornerRadius - 6)
highlightPath.lineWidth = 2
NSColor(white: 1.0, alpha: 0.08).setStroke()
highlightPath.stroke()

NSGraphicsContext.restoreGraphicsState()

// Write PNG.
guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}
let outputURL = URL(fileURLWithPath: "icon-1024.png")
do {
    try pngData.write(to: outputURL)
    print("Wrote \(outputURL.path)")
} catch {
    fputs("Failed to write PNG: \(error)\n", stderr)
    exit(1)
}
