#!/usr/bin/env swift
//
// make_app_icon.swift — draws Porto's app icon and renders the .iconset.
//
// Run with:  swift scripts/make_app_icon.swift
// Then:      iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
//

import AppKit

// macOS "Big Sur" icon grid: 1024×1024 canvas, 824×824 body, 185pt corner radius.
let canvas: CGFloat = 1024
let bodyInset: CGFloat = 100
let bodySize = canvas - bodyInset * 2          // 824
let cornerRadius: CGFloat = 185

let bodyRect = CGRect(x: bodyInset, y: bodyInset, width: bodySize, height: bodySize)

// Palette
let topColor = NSColor(srgbRed: 0x1E / 255, green: 0x3A / 255, blue: 0x8A / 255, alpha: 1) // indigo
let bottomColor = NSColor(srgbRed: 0x06 / 255, green: 0xB6 / 255, blue: 0xD4 / 255, alpha: 1) // cyan

func makeIcon(pixels: Int) -> NSBitmapImageRep? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    context.imageInterpolation = .high
    NSGraphicsContext.current = context

    let scale: CGFloat = CGFloat(pixels) / canvas

    // Draw in the 1024×1024 design space.
    let transform = NSAffineTransform()
    transform.scaleX(by: scale, yBy: scale)
    transform.concat()

    let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: cornerRadius, yRadius: cornerRadius)

    // --- Tile: diagonal gradient -------------------------------------------
    NSGraphicsContext.saveGraphicsState()
    bodyPath.addClip()

    let colors = [topColor.cgColor, bottomColor.cgColor] as CFArray
    let locations: [CGFloat] = [0, 1]
    if let cgGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: locations
    ) {
        let start = CGPoint(x: bodyRect.minX, y: bodyRect.maxY)
        let end = CGPoint(x: bodyRect.maxX, y: bodyRect.minY)
        NSGraphicsContext.current?.cgContext.drawLinearGradient(
            cgGradient,
            start: start,
            end: end,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    // Soft gloss across the top half.
    if let gloss = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [NSColor.white.withAlphaComponent(0.22).cgColor,
                 NSColor.white.withAlphaComponent(0.0).cgColor] as CFArray,
        locations: [0, 1]
    ) {
        NSGraphicsContext.current?.cgContext.drawLinearGradient(
            gloss,
            start: CGPoint(x: 0, y: bodyRect.maxY),
            end: CGPoint(x: 0, y: bodyRect.midY),
            options: [.drawsAfterEndLocation]
        )
    }
    NSGraphicsContext.restoreGraphicsState()

    // Subtle inner highlight along the rim.
    let rim = NSBezierPath(roundedRect: bodyRect.insetBy(dx: 1, dy: 1),
                           xRadius: cornerRadius - 1, yRadius: cornerRadius - 1)
    rim.lineWidth = 2
    NSColor.white.withAlphaComponent(0.28).setStroke()
    rim.stroke()

    // --- Plug glyph ---------------------------------------------------------
    let glyph = NSBezierPath()
    let white = NSColor.white

    // Body
    let plugBody = CGRect(x: 392, y: 379, width: 240, height: 300)
    glyph.append(NSBezierPath(roundedRect: plugBody, xRadius: 62, yRadius: 62))

    // Prongs
    for x in [CGFloat(427), CGFloat(551)] {
        glyph.append(NSBezierPath(roundedRect: CGRect(x: x, y: 679, width: 46, height: 130),
                                  xRadius: 23, yRadius: 23))
    }

    // Cable: drops from the bottom of the plug, then curves right.
    let cable = NSBezierPath()
    cable.lineWidth = 48
    cable.lineCapStyle = .round
    cable.lineJoinStyle = .round
    cable.move(to: CGPoint(x: 512, y: 379))
    cable.line(to: CGPoint(x: 512, y: 300))
    cable.curve(to: CGPoint(x: 660, y: 300),
                controlPoint1: CGPoint(x: 512, y: 220),
                controlPoint2: CGPoint(x: 580, y: 300))

    // Shadow under the glyph.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 14
    shadow.shadowOffset = NSSize(width: 0, height: -6)
    shadow.set()

    white.setFill()
    white.setStroke()
    glyph.fill()
    cable.stroke()
    NSGraphicsContext.restoreGraphicsState()

    return rep
}

// --- Render every required size ---------------------------------------------
let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()      // scripts/
    .deletingLastPathComponent()      // PortBar/
let resources = root.appendingPathComponent("Resources")
let iconset = resources.appendingPathComponent("AppIcon.iconset")

try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for entry in sizes {
    guard let rep = makeIcon(pixels: entry.pixels),
          let png = rep.representation(using: .png, properties: [:]) else {
        fputs("failed to render \(entry.name)\n", stderr)
        exit(1)
    }
    let url = iconset.appendingPathComponent("\(entry.name).png")
    try png.write(to: url)
    print("wrote \(entry.name).png (\(entry.pixels)×\(entry.pixels))")
}

// Also keep a 1024 master PNG for reference.
if let rep = makeIcon(pixels: 1024),
   let png = rep.representation(using: .png, properties: [:]) {
    try? png.write(to: resources.appendingPathComponent("AppIcon.png"))
}

print("done — run: iconutil -c icns \(iconset.path) -o \(resources.appendingPathComponent("AppIcon.icns").path)")