// Renders the `plan` app icon at every .iconset size with CoreGraphics,
// mirroring Assets/AppIcon.svg (hay board + white card + red check).
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func srgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: 1)
}

func makeIcon(size: Int) -> CGImage {
    let scale = CGFloat(size) / 1024
    let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: size * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

    // Hay board (full square, Big Sur-style corner radius).
    ctx.setFillColor(srgb(239/255, 230/255, 199/255))
    ctx.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
                       cornerWidth: 228 * scale, cornerHeight: 228 * scale, transform: nil))
    ctx.fillPath()

    // Card shadow.
    ctx.setFillColor(CGColor(gray: 0, alpha: 0.07))
    ctx.addPath(CGPath(roundedRect: CGRect(x: 236*scale, y: 286*scale, width: 552*scale, height: 452*scale),
                       cornerWidth: 56 * scale, cornerHeight: 56 * scale, transform: nil))
    ctx.fillPath()

    // White task card.
    ctx.setFillColor(srgb(1, 1, 1))
    ctx.addPath(CGPath(roundedRect: CGRect(x: 236*scale, y: 262*scale, width: 552*scale, height: 452*scale),
                       cornerWidth: 56 * scale, cornerHeight: 56 * scale, transform: nil))
    ctx.fillPath()

    // Red done-check.
    let check = CGMutablePath()
    check.move(to: CGPoint(x: 356*scale, y: 522*scale))
    check.addLine(to: CGPoint(x: 470*scale, y: 636*scale))
    check.addLine(to: CGPoint(x: 692*scale, y: 388*scale))
    ctx.setStrokeColor(srgb(217/255, 46/255, 36/255))
    ctx.setLineWidth(76 * scale)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(check)
    ctx.strokePath()

    return ctx.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
for (size, name) in sizes {
    write(makeIcon(size: size), to: outDir.appendingPathComponent(name))
}
print("iconset written to \(outDir.path)")