#!/usr/bin/env swift
// Generates the app icon: a rounded gradient tile with a storage-drive glyph.
// Usage: swift scripts/make-icon.swift <output.png>

import AppKit

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon_1024.png"

let canvas = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: canvas,
    pixelsHigh: canvas,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    FileHandle.standardError.write(Data("Could not allocate icon bitmap\n".utf8))
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high
NSGraphicsContext.current?.shouldAntialias = true

let size = CGFloat(canvas)

// Rounded tile with vertical gradient
let tileRect = NSRect(x: 64, y: 64, width: size - 128, height: size - 128)
let tile = NSBezierPath(roundedRect: tileRect, xRadius: 210, yRadius: 210)
tile.addClip()
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.16, green: 0.30, blue: 0.72, alpha: 1.0),
    NSColor(srgbRed: 0.36, green: 0.20, blue: 0.62, alpha: 1.0)
])!
gradient.draw(in: tileRect, angle: -90)

// Soft highlight
let highlight = NSBezierPath(ovalIn: NSRect(x: 120, y: 520, width: 780, height: 460))
NSColor.white.withAlphaComponent(0.10).setFill()
highlight.fill()

// Storage glyph
if let symbol = NSImage(systemSymbolName: "internaldrive.fill", accessibilityDescription: "Storage") {
    let config = NSImage.SymbolConfiguration(pointSize: 420, weight: .regular)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let glyph = symbol.withSymbolConfiguration(config) {
        let glyphSize = glyph.size
        let target = NSRect(
            x: (size - glyphSize.width) / 2,
            y: (size - glyphSize.height) / 2,
            width: glyphSize.width,
            height: glyphSize.height
        )
        glyph.draw(in: target)
    }
}

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Failed to encode icon\n".utf8))
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
