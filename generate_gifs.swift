import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct RGB {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
}

struct IconSpec {
    let src: String
    let out: String
    let primary: RGB
    let secondary: RGB
    let mode: String // "active", "idle", "badge"
}

let baseDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".gemini/antigravity/scratch/ollama-discord-assets")
let srcDir = baseDir.appendingPathComponent(".src_icons")

let specs: [IconSpec] = [
    IconSpec(src: "ollama.png",          out: "ollama-idle.gif",    primary: RGB(r: 0.78, g: 0.85, b: 0.94), secondary: RGB(r: 0.45, g: 0.55, b: 0.68), mode: "idle"),
    IconSpec(src: "ollama.png",          out: "ollama-active.gif",  primary: RGB(r: 0.35, g: 0.82, b: 0.98), secondary: RGB(r: 0.88, g: 0.95, b: 1.00), mode: "active"),
    IconSpec(src: "liquid.png",          out: "liquid-active.gif",  primary: RGB(r: 0.38, g: 0.68, b: 1.00), secondary: RGB(r: 0.68, g: 0.52, b: 1.00), mode: "active"),
    IconSpec(src: "qwen-color.png",      out: "qwen-active.gif",    primary: RGB(r: 0.55, g: 0.36, b: 0.96), secondary: RGB(r: 0.39, g: 0.40, b: 0.95), mode: "active"),
    IconSpec(src: "meta-color.png",      out: "meta-active.gif",    primary: RGB(r: 0.15, g: 0.55, b: 1.00), secondary: RGB(r: 0.04, g: 0.75, b: 0.88), mode: "active"),
    IconSpec(src: "gemma-color.png",     out: "gemma-active.gif",   primary: RGB(r: 0.25, g: 0.68, b: 0.98), secondary: RGB(r: 0.52, g: 0.56, b: 0.98), mode: "active"),
    IconSpec(src: "deepseek-color.png",  out: "deepseek-active.gif",primary: RGB(r: 0.30, g: 0.40, b: 0.98), secondary: RGB(r: 0.22, g: 0.74, b: 0.97), mode: "active"),
    IconSpec(src: "mistral-color.png",   out: "mistral-active.gif", primary: RGB(r: 0.98, g: 0.48, b: 0.12), secondary: RGB(r: 0.98, g: 0.78, b: 0.15), mode: "active"),
    IconSpec(src: "microsoft-color.png", out: "phi-active.gif",     primary: RGB(r: 0.06, g: 0.68, b: 0.92), secondary: RGB(r: 0.10, g: 0.78, b: 0.58), mode: "active"),
    IconSpec(src: "cohere-color.png",    out: "cohere-active.gif",  primary: RGB(r: 0.24, g: 0.82, b: 0.62), secondary: RGB(r: 0.95, g: 0.45, b: 0.68), mode: "active"),
    IconSpec(src: "openai.png",          out: "openai-active.gif",  primary: RGB(r: 0.10, g: 0.78, b: 0.55), secondary: RGB(r: 0.86, g: 0.96, b: 0.92), mode: "active"),
    IconSpec(src: "claude-color.png",    out: "claude-active.gif",  primary: RGB(r: 0.95, g: 0.56, b: 0.24), secondary: RGB(r: 0.98, g: 0.76, b: 0.42), mode: "active"),
    IconSpec(src: "apple.png",           out: "apple-badge.gif",    primary: RGB(r: 0.82, g: 0.88, b: 0.98), secondary: RGB(r: 0.45, g: 0.62, b: 0.92), mode: "badge"),
]

func loadCGImage(url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

func makeContext(size: Int) -> CGContext? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    return CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
}

func drawBackground(ctx: CGContext, size: CGFloat, primary: RGB, secondary: RGB, glowAlpha: CGFloat) {
    // Rich dark Discord-native background
    ctx.setFillColor(red: 0.06, green: 0.07, blue: 0.10, alpha: 1.0)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

    let center = CGPoint(x: size / 2, y: size / 2)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(red: primary.r, green: primary.g, blue: primary.b, alpha: glowAlpha),
        CGColor(red: secondary.r, green: secondary.g, blue: secondary.b, alpha: glowAlpha * 0.4),
        CGColor(red: 0.06, green: 0.07, blue: 0.10, alpha: 0.0)
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 0.45, 1.0]) {
        ctx.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: size * 0.05,
            endCenter: center,
            endRadius: size * 0.49,
            options: []
        )
    }
}

func renderFrame(spec: IconSpec, icon: CGImage, size: Int, frameIdx: Int, totalFrames: Int) -> CGImage? {
    guard let ctx = makeContext(size: size) else { return nil }
    let s = CGFloat(size)
    let t = CGFloat(frameIdx) / CGFloat(totalFrames)
    let angle = t * 2.0 * .pi
    let pulse = 0.5 + 0.5 * sin(angle) // 0..1 smooth sine
    let center = CGPoint(x: s / 2, y: s / 2)

    if spec.mode == "active" {
        drawBackground(ctx: ctx, size: s, primary: spec.primary, secondary: spec.secondary, glowAlpha: 0.18 + 0.08 * pulse)

        let ringRadius = s * 0.39
        // Subtle base track ring
        ctx.saveGState()
        ctx.setStrokeColor(red: spec.primary.r, green: spec.primary.g, blue: spec.primary.b, alpha: 0.16)
        ctx.setLineWidth(s * 0.016)
        ctx.addArc(center: center, radius: ringRadius, startAngle: 0, endAngle: 2.0 * .pi, clockwise: false)
        ctx.strokePath()
        ctx.restoreGState()

        // Smooth rotating gradient orbital arc (drawn as segmented tail for smooth fade)
        let segments = 28
        let arcSpan: CGFloat = .pi * 0.72
        let headAngle = -angle + .pi / 2.0
        for i in 0..<segments {
            let frac = CGFloat(i) / CGFloat(segments) // 0 = tail, 1 = head
            let a0 = headAngle - arcSpan * (1.0 - frac)
            let a1 = headAngle - arcSpan * (1.0 - CGFloat(i + 1) / CGFloat(segments))
            let r = spec.secondary.r * (1.0 - frac) + spec.primary.r * frac
            let g = spec.secondary.g * (1.0 - frac) + spec.primary.g * frac
            let b = spec.secondary.b * (1.0 - frac) + spec.primary.b * frac
            let alpha = pow(frac, 1.8) * 0.95
            ctx.saveGState()
            ctx.setStrokeColor(red: r, green: g, blue: b, alpha: alpha)
            ctx.setLineWidth(s * (0.014 + 0.012 * frac))
            ctx.setLineCap(.round)
            ctx.addArc(center: center, radius: ringRadius, startAngle: a0, endAngle: a1, clockwise: false)
            ctx.strokePath()
            ctx.restoreGState()
        }

        // Glowing leading dot on orbit
        let dotX = center.x + cos(headAngle) * ringRadius
        let dotY = center.y + sin(headAngle) * ringRadius
        ctx.saveGState()
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92)
        let dotR = s * 0.022
        ctx.fillEllipse(in: CGRect(x: dotX - dotR, y: dotY - dotR, width: dotR * 2, height: dotR * 2))
        ctx.restoreGState()

        // Subtle counter-arc for symmetry
        let oppAngle = headAngle + .pi
        ctx.saveGState()
        ctx.setStrokeColor(red: spec.secondary.r, green: spec.secondary.g, blue: spec.secondary.b, alpha: 0.32)
        ctx.setLineWidth(s * 0.012)
        ctx.setLineCap(.round)
        ctx.addArc(center: center, radius: ringRadius, startAngle: oppAngle - 0.35, endAngle: oppAngle, clockwise: false)
        ctx.strokePath()
        ctx.restoreGState()

        // Central icon with very subtle breathing scale
        let iconSide = s * (0.49 + 0.02 * pulse)
        let iconRect = CGRect(x: center.x - iconSide / 2, y: center.y - iconSide / 2, width: iconSide, height: iconSide)
        ctx.draw(icon, in: iconRect)

    } else if spec.mode == "idle" {
        drawBackground(ctx: ctx, size: s, primary: spec.primary, secondary: spec.secondary, glowAlpha: 0.10 + 0.06 * pulse)

        // Calm breathing ring
        let ringRadius = s * (0.36 + 0.03 * pulse)
        ctx.saveGState()
        ctx.setStrokeColor(red: spec.primary.r, green: spec.primary.g, blue: spec.primary.b, alpha: 0.18 + 0.25 * (1.0 - pulse))
        ctx.setLineWidth(s * 0.015)
        ctx.addArc(center: center, radius: ringRadius, startAngle: 0, endAngle: 2.0 * .pi, clockwise: false)
        ctx.strokePath()
        ctx.restoreGState()

        // Inner thin ring
        ctx.saveGState()
        ctx.setStrokeColor(red: spec.secondary.r, green: spec.secondary.g, blue: spec.secondary.b, alpha: 0.22)
        ctx.setLineWidth(s * 0.010)
        ctx.addArc(center: center, radius: s * 0.34, startAngle: 0, endAngle: 2.0 * .pi, clockwise: false)
        ctx.strokePath()
        ctx.restoreGState()

        let iconSide = s * (0.48 + 0.015 * pulse)
        let iconRect = CGRect(x: center.x - iconSide / 2, y: center.y - iconSide / 2, width: iconSide, height: iconSide)
        ctx.draw(icon, in: iconRect)

    } else {
        // Badge mode (192x192 small image)
        drawBackground(ctx: ctx, size: s, primary: spec.primary, secondary: spec.secondary, glowAlpha: 0.14 + 0.12 * pulse)

        let ringRadius = s * 0.42
        ctx.saveGState()
        ctx.setStrokeColor(red: spec.primary.r, green: spec.primary.g, blue: spec.primary.b, alpha: 0.25 + 0.40 * pulse)
        ctx.setLineWidth(s * 0.025)
        ctx.addArc(center: center, radius: ringRadius, startAngle: 0, endAngle: 2.0 * .pi, clockwise: false)
        ctx.strokePath()
        ctx.restoreGState()

        let iconSide = s * (0.56 + 0.03 * pulse)
        let iconRect = CGRect(x: center.x - iconSide / 2, y: center.y - iconSide / 2, width: iconSide, height: iconSide)
        ctx.draw(icon, in: iconRect)
    }

    return ctx.makeImage()
}

for spec in specs {
    let iconURL = srcDir.appendingPathComponent(spec.src)
    guard let icon = loadCGImage(url: iconURL) else {
        fputs("Failed to load \(spec.src)\n", stderr)
        exit(1)
    }

    let isBadge = spec.mode == "badge"
    let size = isBadge ? 192 : 384
    let frames = spec.mode == "active" ? 30 : 32
    let delay = spec.mode == "active" ? 0.05 : 0.065

    let outURL = baseDir.appendingPathComponent(spec.out)
    guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.gif.identifier as CFString, frames, nil) else {
        fputs("Failed to create GIF destination for \(spec.out)\n", stderr)
        exit(1)
    }

    let gifProps: [CFString: Any] = [
        kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFLoopCount: 0
        ]
    ]
    CGImageDestinationSetProperties(dest, gifProps as CFDictionary)

    let frameProps: [CFString: Any] = [
        kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFDelayTime: delay,
            kCGImagePropertyGIFUnclampedDelayTime: delay
        ]
    ]

    for f in 0..<frames {
        guard let frameImg = renderFrame(spec: spec, icon: icon, size: size, frameIdx: f, totalFrames: frames) else {
            fputs("Failed rendering frame \(f) for \(spec.out)\n", stderr)
            exit(1)
        }
        CGImageDestinationAddImage(dest, frameImg, frameProps as CFDictionary)
    }

    if !CGImageDestinationFinalize(dest) {
        fputs("Failed finalizing \(spec.out)\n", stderr)
        exit(1)
    }
    print("Generated \(spec.out)")
}
