import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct RGB {
    let r: Float
    let g: Float
    let b: Float
}

struct IconSpec {
    let src: String
    let out: String
    let stops: [RGB] // 3 or 4 cyclic aurora color stops
    let mode: String // "active", "idle", "badge"
}

let args = CommandLine.arguments
var onlyFilter: Set<String>? = nil
var customSrcDir: URL? = nil
for i in 1..<args.count {
    if args[i] == "--only", i + 1 < args.count {
        onlyFilter = Set(args[i + 1].split(separator: ",").map(String.init))
    } else if args[i] == "--src", i + 1 < args.count {
        customSrcDir = URL(fileURLWithPath: args[i + 1])
    }
}

let home = FileManager.default.homeDirectoryForCurrentUser
let baseDir = home.appendingPathComponent(".gemini/antigravity/scratch/ollama-discord-assets")
let srcDir = customSrcDir ?? baseDir.appendingPathComponent(".src_icons")

func hex(_ value: UInt32) -> RGB {
    RGB(
        r: Float((value >> 16) & 0xFF) / 255.0,
        g: Float((value >> 8) & 0xFF) / 255.0,
        b: Float(value & 0xFF) / 255.0
    )
}

let specs: [IconSpec] = [
    IconSpec(src: "ollama.png",          out: "ollama-idle.gif",     stops: [hex(0x64748B), hex(0x94A3B8), hex(0x475569), hex(0xCBD5E1)], mode: "idle"),
    IconSpec(src: "ollama.png",          out: "ollama-active.gif",   stops: [hex(0x38BDF8), hex(0x818CF8), hex(0xE0F2FE), hex(0x22D3EE)], mode: "active"),
    IconSpec(src: "liquid.png",          out: "liquid-active.gif",   stops: [hex(0x38BDF8), hex(0x6366F1), hex(0xC084FC), hex(0x22D3EE)], mode: "active"),
    IconSpec(src: "qwen-color.png",      out: "qwen-active.gif",     stops: [hex(0x8B5CF6), hex(0x6366F1), hex(0xE879F9), hex(0x38BDF8)], mode: "active"),
    IconSpec(src: "meta-color.png",      out: "meta-active.gif",     stops: [hex(0x0081FB), hex(0x06B6D4), hex(0x60A5FA), hex(0x3B82F6)], mode: "active"),
    IconSpec(src: "gemma-color.png",     out: "gemma-active.gif",    stops: [hex(0x38BDF8), hex(0x818CF8), hex(0xF472B6), hex(0x60A5FA)], mode: "active"),
    IconSpec(src: "deepseek-color.png",  out: "deepseek-active.gif", stops: [hex(0x3B82F6), hex(0x6366F1), hex(0x22D3EE), hex(0x2563EB)], mode: "active"),
    IconSpec(src: "mistral-color.png",   out: "mistral-active.gif",  stops: [hex(0xF97316), hex(0xFACC15), hex(0xFB7185), hex(0xF59E0B)], mode: "active"),
    IconSpec(src: "microsoft-color.png", out: "phi-active.gif",      stops: [hex(0x0EA5E9), hex(0x10B981), hex(0x3B82F6), hex(0x38BDF8)], mode: "active"),
    IconSpec(src: "cohere-color.png",    out: "cohere-active.gif",   stops: [hex(0x2DD4BF), hex(0xFB7185), hex(0xA78BFA), hex(0x34D399)], mode: "active"),
    IconSpec(src: "openai.png",          out: "openai-active.gif",   stops: [hex(0x10B981), hex(0x06B6D4), hex(0xA7F3D0), hex(0x3B82F6)], mode: "active"),
    IconSpec(src: "claude-color.png",    out: "claude-active.gif",   stops: [hex(0xF59E0B), hex(0xFB7185), hex(0xFDBA74), hex(0xEA580C)], mode: "active"),
    IconSpec(src: "apple.png",           out: "apple-badge.gif",     stops: [hex(0xE2E8F0), hex(0x38BDF8), hex(0x818CF8), hex(0x94A3B8)], mode: "badge"),
]

@inline(__always)
func clamp01(_ x: Float) -> Float {
    x < 0 ? 0 : (x > 1 ? 1 : x)
}

@inline(__always)
func smoothstep(_ e0: Float, _ e1: Float, _ x: Float) -> Float {
    let t = clamp01((x - e0) / (e1 - e0))
    return t * t * (3.0 - 2.0 * t)
}

@inline(__always)
func sampleCyclicStops(_ stops: [RGB], t: Float) -> RGB {
    let wrapped = t - floor(t)
    let scaled = wrapped * Float(stops.count)
    let i0 = Int(scaled) % stops.count
    let i1 = (i0 + 1) % stops.count
    let f = scaled - floor(scaled)
    // Smooth cubic blend between palette stops
    let u = f * f * (3.0 - 2.0 * f)
    let a = stops[i0]
    let b = stops[i1]
    return RGB(
        r: a.r + (b.r - a.r) * u,
        g: a.g + (b.g - a.g) * u,
        b: a.b + (b.b - a.b) * u
    )
}

/// Signed distance to a centered rounded rectangle (negative inside, positive outside).
@inline(__always)
func roundedBoxSDF(px: Float, py: Float, halfW: Float, halfH: Float, radius: Float) -> Float {
    let qx = abs(px) - halfW + radius
    let qy = abs(py) - halfH + radius
    let outLen = hypot(max(qx, 0), max(qy, 0))
    let inDist = min(max(qx, qy), 0)
    return outLen + inDist - radius
}

func loadIconRGBA(url: URL, targetSize: Int, iconScale: Float) -> [UInt8]? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let cgImg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        return nil
    }
    var buf = [UInt8](repeating: 0, count: targetSize * targetSize * 4)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: &buf,
        width: targetSize,
        height: targetSize,
        bitsPerComponent: 8,
        bytesPerRow: targetSize * 4,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    let s = CGFloat(targetSize)
    let side = s * CGFloat(iconScale)
    let rect = CGRect(x: (s - side) / 2.0, y: (s - side) / 2.0, width: side, height: side)

    // Soft ambient shadow behind logo for crisp lift off dark glass
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.015), blur: s * 0.045, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.65))
    ctx.draw(cgImg, in: rect)
    ctx.restoreGState()

    return buf
}

// MARK: - Median-Cut Palette Quantizer + Floyd-Steinberg Dithering

struct ColorBox {
    var indices: [Int]
    var rMin: Int, rMax: Int
    var gMin: Int, gMax: Int
    var bMin: Int, bMax: Int

    var largestSpan: Int {
        max(rMax - rMin, max(gMax - gMin, bMax - bMin))
    }
}

func quantizeToIndexedCGImage(rgba: [UInt8], width: Int, height: Int) -> CGImage? {
    let pixelCount = width * height

    // Build adaptive 256-color palette cleanly from pixel sample + slight Bayer pre-dither
    // Using unique/deduplicated quantized 6-bit-or-full buckets avoids wasting palette slots on solid bg
    var colorCounts: [UInt32: Int] = [:]
    colorCounts.reserveCapacity(8192)
    let strideStep = pixelCount > 100_000 ? 2 : 1
    for y in stride(from: 0, to: height, by: strideStep) {
        for x in stride(from: 0, to: width, by: strideStep) {
            let idx = (y * width + x) * 4
            let key = (UInt32(rgba[idx]) << 16) | (UInt32(rgba[idx + 1]) << 8) | UInt32(rgba[idx + 2])
            colorCounts[key, default: 0] += 1
        }
    }

    var sampleColors: [(r: UInt8, g: UInt8, b: UInt8, weight: Int)] = []
    sampleColors.reserveCapacity(colorCounts.count)
    for (key, cnt) in colorCounts {
        let r = UInt8((key >> 16) & 0xFF)
        let g = UInt8((key >> 8) & 0xFF)
        let b = UInt8(key & 0xFF)
        // Sublinear weight so gradients get lots of palette stops even against huge solid bg
        sampleColors.append((r, g, b, max(1, Int(Double(cnt).squareRoot()))))
    }

    func makeBox(_ idxs: [Int]) -> ColorBox {
        var rMin = 255, rMax = 0, gMin = 255, gMax = 0, bMin = 255, bMax = 0
        for i in idxs {
            let c = sampleColors[i]
            let r = Int(c.r), g = Int(c.g), b = Int(c.b)
            if r < rMin { rMin = r }; if r > rMax { rMax = r }
            if g < gMin { gMin = g }; if g > gMax { gMax = g }
            if b < bMin { bMin = b }; if b > bMax { bMax = b }
        }
        return ColorBox(indices: idxs, rMin: rMin, rMax: rMax, gMin: gMin, gMax: gMax, bMin: bMin, bMax: bMax)
    }

    var boxes: [ColorBox] = [makeBox(Array(0..<sampleColors.count))]
    while boxes.count < 256 {
        var bestIdx = -1
        var bestSpan = 0
        for i in 0..<boxes.count {
            if boxes[i].indices.count > 1 && boxes[i].largestSpan > bestSpan {
                bestSpan = boxes[i].largestSpan
                bestIdx = i
            }
        }
        if bestIdx < 0 || bestSpan == 0 { break }

        var box = boxes.remove(at: bestIdx)
        let rSpan = box.rMax - box.rMin
        let gSpan = box.gMax - box.gMin
        let bSpan = box.bMax - box.bMin

        if rSpan >= gSpan && rSpan >= bSpan {
            box.indices.sort { sampleColors[$0].r < sampleColors[$1].r }
        } else if gSpan >= bSpan {
            box.indices.sort { sampleColors[$0].g < sampleColors[$1].g }
        } else {
            box.indices.sort { sampleColors[$0].b < sampleColors[$1].b }
        }
        let mid = box.indices.count / 2
        boxes.append(makeBox(Array(box.indices[..<mid])))
        boxes.append(makeBox(Array(box.indices[mid...])))
    }

    struct PalEntry { let r: Int; let g: Int; let b: Int; let lum: Int }
    var palette: [PalEntry] = []
    palette.reserveCapacity(256)
    for box in boxes {
        var rSum = 0, gSum = 0, bSum = 0, wSum = 0
        for i in box.indices {
            let c = sampleColors[i]
            let w = c.weight
            rSum += Int(c.r) * w; gSum += Int(c.g) * w; bSum += Int(c.b) * w; wSum += w
        }
        let n = max(1, wSum)
        let r = rSum / n, g = gSum / n, b = bSum / n
        let lum = (299 * r + 587 * g + 114 * b) / 1000
        palette.append(PalEntry(r: r, g: g, b: b, lum: lum))
    }
    palette.sort { $0.lum < $1.lum }

    // 5-bit LUT cache? No, luminance-sorted early exit over <=256 palette entries is exact 8-bit & super fast!
    let pCount = palette.count
    var pR = [Int](repeating: 0, count: pCount)
    var pG = [Int](repeating: 0, count: pCount)
    var pB = [Int](repeating: 0, count: pCount)
    for i in 0..<pCount {
        pR[i] = palette[i].r
        pG[i] = palette[i].g
        pB[i] = palette[i].b
    }

    @inline(__always)
    func nearestPaletteIndex(_ r: Int, _ g: Int, _ b: Int) -> Int {
        var bestIdx = 0
        var bestDist = Int.max
        for i in 0..<pCount {
            let dr = r - pR[i]
            let dg = g - pG[i]
            let db = b - pB[i]
            let d = dr * dr * 2 + dg * dg * 4 + db * db
            if d < bestDist {
                bestDist = d
                bestIdx = i
                if d == 0 { break }
            }
        }
        return bestIdx
    }

    // Float error buffer for Floyd-Steinberg diffusion (scaled by 16 for exact integer math or Float)
    var workR = [Float](repeating: 0, count: pixelCount)
    var workG = [Float](repeating: 0, count: pixelCount)
    var workB = [Float](repeating: 0, count: pixelCount)
    for i in 0..<pixelCount {
        workR[i] = Float(rgba[i * 4])
        workG[i] = Float(rgba[i * 4 + 1])
        workB[i] = Float(rgba[i * 4 + 2])
    }

    var indexedPixels = [UInt8](repeating: 0, count: pixelCount)
    for y in 0..<height {
        let rowOffset = y * width
        for x in 0..<width {
            let p = rowOffset + x
            let rOld = workR[p]
            let gOld = workG[p]
            let bOld = workB[p]
            let rc = max(0, min(255, Int(rOld.rounded())))
            let gc = max(0, min(255, Int(gOld.rounded())))
            let bc = max(0, min(255, Int(bOld.rounded())))

            let best = nearestPaletteIndex(rc, gc, bc)
            indexedPixels[p] = UInt8(best)

            let er = Float(rc - pR[best]) * 0.88
            let eg = Float(gc - pG[best]) * 0.88
            let eb = Float(bc - pB[best]) * 0.88

            if x + 1 < width {
                let np = p + 1
                workR[np] += er * (7.0 / 16.0)
                workG[np] += eg * (7.0 / 16.0)
                workB[np] += eb * (7.0 / 16.0)
            }
            if y + 1 < height {
                if x > 0 {
                    let np = p + width - 1
                    workR[np] += er * (3.0 / 16.0)
                    workG[np] += eg * (3.0 / 16.0)
                    workB[np] += eb * (3.0 / 16.0)
                }
                do {
                    let np = p + width
                    workR[np] += er * (5.0 / 16.0)
                    workG[np] += eg * (5.0 / 16.0)
                    workB[np] += eb * (5.0 / 16.0)
                }
                if x + 1 < width {
                    let np = p + width + 1
                    workR[np] += er * (1.0 / 16.0)
                    workG[np] += eg * (1.0 / 16.0)
                    workB[np] += eb * (1.0 / 16.0)
                }
            }
        }
    }

    // Build CoreGraphics Indexed ColorSpace + 8-bit indexed CGImage (0 loss inside ImageIO!)
    var colorTable = [UInt8](repeating: 0, count: 256 * 3)
    for i in 0..<pCount {
        colorTable[i * 3]     = UInt8(pR[i])
        colorTable[i * 3 + 1] = UInt8(pG[i])
        colorTable[i * 3 + 2] = UInt8(pB[i])
    }

    let baseCS = CGColorSpaceCreateDeviceRGB()
    guard let indexedCS = colorTable.withUnsafeBufferPointer({ ptr in
        CGColorSpace(indexedBaseSpace: baseCS, last: 255, colorTable: ptr.baseAddress!)
    }) else { return nil }

    let data = Data(indexedPixels)
    guard let provider = CGDataProvider(data: data as CFData) else { return nil }
    return CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 8,
        bytesPerRow: width,
        space: indexedCS,
        bitmapInfo: CGBitmapInfo(rawValue: 0),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )
}

func renderFramePixels(spec: IconSpec, logoRGBA: [UInt8], size: Int, frameIdx: Int, totalFrames: Int) -> [UInt8] {
    var out = [UInt8](repeating: 0, count: size * size * 4)
    let s = Float(size)
    let half = s * 0.5
    let phase = Float(frameIdx) / Float(totalFrames) // 0 ..< 1 seamless loop
    let twoPi = Float.pi * 2.0
    let pulse = 0.5 - 0.5 * cos(phase * twoPi) // 0 -> 1 -> 0 smooth periodic wave

    // Specular sheen sweeps smoothly once across first 65% of loop, rests cleanly
    let sweepProgress = clamp01(phase / 0.65)
    let sweepPos: Float = -1.25 + 2.5 * (sweepProgress * sweepProgress * (3.0 - 2.0 * sweepProgress))
    let sweepActive: Float = phase < 0.65 ? sin(sweepProgress * Float.pi) : 0.0

    let bgR: Float = 0.051 // #0D1017 - Discord dark surface match
    let bgG: Float = 0.063
    let bgB: Float = 0.090

    // 4x4 Bayer matrix normalized to [-0.47, +0.47]/255 to break 8-bit gradient quantization
    let bayer4: [Float] = [
        -0.46875,  0.03125, -0.34375,  0.15625,
         0.28125, -0.21875,  0.40625, -0.09375,
        -0.28125,  0.21875, -0.40625,  0.09375,
         0.46875, -0.03125,  0.34375, -0.15625
    ]

    if spec.mode == "badge" {
        // Discord crops small_image into a 24x24 circle: make the entire surface clean & punchy
        let sheenBand: Float = 0.24
        for y in 0..<size {
            let ny = (Float(y) + 0.5 - half) / half // -1 .. 1
            let by = (y & 3) << 2
            for x in 0..<size {
                let nx = (Float(x) + 0.5 - half) / half
                let rDist = hypot(nx, ny)
                let ang = atan2(ny, nx) / twoPi + 0.5
                let col = sampleCyclicStops(spec.stops, t: ang + phase)

                // Soft central Apple Silicon iridescent halo behind crisp white Apple mark
                let coreHalo = exp(-rDist * rDist * 3.8) * (0.20 + 0.09 * pulse)
                let ringGlow = exp(-pow((rDist - 0.56) / 0.20, 2.0)) * (0.10 + 0.06 * pulse)
                let glow = coreHalo + ringGlow

                // Diagonal metallic sheen sweep
                let diag = (nx * 0.72 + ny * 0.69)
                let sheen = exp(-pow((diag - sweepPos) / sheenBand, 2.0)) * 0.14 * sweepActive

                let dither = bayer4[by + (x & 3)] / 255.0
                var r = bgR + col.r * glow + sheen + dither
                var g = bgG + col.g * glow + sheen + dither
                var b = bgB + col.b * glow + sheen + dither

                // Composite pre-multiplied crisp logo
                let p = (y * size + x) * 4
                let la = Float(logoRGBA[p + 3]) / 255.0
                if la > 0 {
                    let lr = Float(logoRGBA[p]) / 255.0
                    let lg = Float(logoRGBA[p + 1]) / 255.0
                    let lb = Float(logoRGBA[p + 2]) / 255.0
                    let inv = 1.0 - la
                    r = lr + r * inv
                    g = lg + g * inv
                    b = lb + b * inv
                }

                out[p]     = UInt8(clamp01(r) * 255.0)
                out[p + 1] = UInt8(clamp01(g) * 255.0)
                out[p + 2] = UInt8(clamp01(b) * 255.0)
                out[p + 3] = 255
            }
        }
        return out
    }

    // Active & Idle Modes: Liquid Glass Squircle Tile with Apple Intelligence Aurora Edge
    let cardHalf = s * 0.400
    let cornerR  = s * 0.155
    let invHalf  = 1.0 / half

    let isIdle = (spec.mode == "idle")
    let rimThickness: Float = s * (isIdle ? 0.0055 : 0.0080)
    let outerBloomSigma: Float = s * (isIdle ? 0.044 : 0.052)
    let innerBleedSigma: Float = s * 0.062

    for y in 0..<size {
        let py = Float(y) + 0.5 - half
        let ny = py * invHalf
        let by = (y & 3) << 2
        for x in 0..<size {
            let px = Float(x) + 0.5 - half
            let nx = px * invHalf

            let d = roundedBoxSDF(px: px, py: py, halfW: cardHalf, halfH: cardHalf, radius: cornerR)
            // Conic angle normalized 0..1
            let theta = atan2(ny, nx) / twoPi + 0.5
            let gradPhase = isIdle ? (theta * 0.5 + 0.15 * sin(phase * twoPi)) : (theta - phase)
            let edgeCol = sampleCyclicStops(spec.stops, t: gradPhase)

            // Dual-lobe energy wave around orbit for rich Siri / Apple Intelligence motion
            let focusAngle = isIdle ? 0.0 : (phase * twoPi)
            let angDiff = atan2(ny, nx) - focusAngle
            let primaryWave = pow(max(0.0, 0.5 + 0.5 * cos(angDiff)), 1.9)
            let secondaryWave = pow(max(0.0, 0.5 - 0.5 * cos(angDiff)), 3.2) * 0.45
            let highlightBoost: Float = isIdle ? (0.40 + 0.42 * pulse) : (0.58 + 0.62 * max(primaryWave, secondaryWave))

            // Start from clean solid dark background
            var r = bgR
            var g = bgG
            var b = bgB

            if d < 0 {
                // Inside Dark Glass Tile
                let glassBaseR: Float = 0.070 // #121722
                let glassBaseG: Float = 0.088
                let glassBaseB: Float = 0.128

                let bevelTint = clamp01((-ny - nx * 0.35) * 0.25 + 0.5) * 0.016
                let bleed = exp(-(d * d) / (2.0 * innerBleedSigma * innerBleedSigma)) * (isIdle ? 0.07 : 0.18) * highlightBoost
                let distCenter = hypot(nx, ny)
                let centerGlow = exp(-distCenter * distCenter * 4.2) * (isIdle ? (0.05 + 0.05 * pulse) : 0.14)

                // Diagonal specular sheen sweeping smoothly over the glass
                let diag = nx * 0.75 + ny * 0.66
                let sheen = exp(-pow((diag - sweepPos) / 0.18, 2.0)) * (isIdle ? 0.05 : 0.12) * sweepActive

                r = glassBaseR + bevelTint + edgeCol.r * (bleed + centerGlow) + sheen
                g = glassBaseG + bevelTint + edgeCol.g * (bleed + centerGlow) + sheen
                b = glassBaseB + bevelTint + edgeCol.b * (bleed + centerGlow) + sheen
            } else {
                // Outside Tile: soft gaussian neon aurora halo fading cleanly into bg
                let edgeMask = smoothstep(half * 0.98, half * 0.78, max(abs(px), abs(py)))
                let outerGlow = exp(-(d * d) / (2.0 * outerBloomSigma * outerBloomSigma)) * (isIdle ? 0.16 : 0.36) * highlightBoost * edgeMask
                r += edgeCol.r * outerGlow
                g += edgeCol.g * outerGlow
                b += edgeCol.b * outerGlow
            }

            // Crisp continuous luminous squircle border
            let rimAlpha = (1.0 - smoothstep(rimThickness * 0.35, rimThickness * 1.15, abs(d))) * (isIdle ? (0.35 + 0.32 * pulse) : min(1.0, 0.75 + 0.25 * primaryWave))
            if rimAlpha > 0 {
                let whiteMix = isIdle ? 0.18 : (0.38 * pow(primaryWave, 1.5))
                let rimR = edgeCol.r + (1.0 - edgeCol.r) * whiteMix
                let rimG = edgeCol.g + (1.0 - edgeCol.g) * whiteMix
                let rimB = edgeCol.b + (1.0 - edgeCol.b) * whiteMix
                r = r * (1.0 - rimAlpha) + rimR * rimAlpha
                g = g * (1.0 - rimAlpha) + rimG * rimAlpha
                b = b * (1.0 - rimAlpha) + rimB * rimAlpha
            }

            // Apply sub-LSB Bayer pre-dither to smooth subtle gradients before quantization
            let dither = bayer4[by + (x & 3)] / 255.0
            r += dither
            g += dither
            b += dither

            // Composite crisp pre-rendered logo on top (strictly pixel-locked!)
            let p = (y * size + x) * 4
            let la = Float(logoRGBA[p + 3]) / 255.0
            if la > 0 {
                let lr = Float(logoRGBA[p]) / 255.0
                let lg = Float(logoRGBA[p + 1]) / 255.0
                let lb = Float(logoRGBA[p + 2]) / 255.0
                let inv = 1.0 - la
                r = lr + r * inv
                g = lg + g * inv
                b = lb + b * inv
            }

            out[p]     = UInt8(clamp01(r) * 255.0)
            out[p + 1] = UInt8(clamp01(g) * 255.0)
            out[p + 2] = UInt8(clamp01(b) * 255.0)
            out[p + 3] = 255
        }
    }

    return out
}

for spec in specs {
    if let filter = onlyFilter, !filter.contains(spec.out) {
        continue
    }
    let iconURL = srcDir.appendingPathComponent(spec.src)
    let isBadge = spec.mode == "badge"
    let size = isBadge ? 192 : 384
    let iconScale: Float = isBadge ? 0.62 : 0.52

    guard let logoRGBA = loadIconRGBA(url: iconURL, targetSize: size, iconScale: iconScale) else {
        fputs("Failed to load \(iconURL.path)\n", stderr)
        exit(1)
    }

    let frames = isBadge ? 24 : (spec.mode == "idle" ? 28 : 32)
    let delay = isBadge ? 0.065 : (spec.mode == "idle" ? 0.08 : 0.05)

    let outURL = baseDir.appendingPathComponent(spec.out)
    guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.gif.identifier as CFString, frames, nil) else {
        fputs("Failed to create GIF destination for \(spec.out)\n", stderr)
        exit(1)
    }

    let gifProps: [CFString: Any] = [
        kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
    ]
    CGImageDestinationSetProperties(dest, gifProps as CFDictionary)

    let frameProps: [CFString: Any] = [
        kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFDelayTime: delay,
            kCGImagePropertyGIFUnclampedDelayTime: delay
        ]
    ]

    for f in 0..<frames {
        let rgba = renderFramePixels(spec: spec, logoRGBA: logoRGBA, size: size, frameIdx: f, totalFrames: frames)
        guard let indexedImg = quantizeToIndexedCGImage(rgba: rgba, width: size, height: size) else {
            fputs("Failed quantizing frame \(f) for \(spec.out)\n", stderr)
            exit(1)
        }
        CGImageDestinationAddImage(dest, indexedImg, frameProps as CFDictionary)
    }

    if !CGImageDestinationFinalize(dest) {
        fputs("Failed finalizing \(spec.out)\n", stderr)
        exit(1)
    }
    print("Generated \(spec.out)")
}
