// Rebuild with: swift Scripts/GenerateAppIcon.swift (from the repository root).
// Flat A-1 artwork. iOS applies the outer corner mask; the source is opaque and square.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let output = URL(fileURLWithPath: "WorkSpotMap/Assets.xcassets/AppIcon.appiconset")
let sizes: [(String, String, [Int])] = [
    ("iphone", "20", [2, 3]), ("iphone", "29", [2, 3]),
    ("iphone", "40", [2, 3]), ("iphone", "60", [2, 3]),
    ("ipad", "20", [1, 2]), ("ipad", "29", [1, 2]),
    ("ipad", "40", [1, 2]), ("ipad", "76", [1, 2]),
    ("ipad", "83.5", [2]), ("ios-marketing", "1024", [1])
]
var entries = [[String: String]]()
var rendered = Set<Int>()
for (idiom, size, scales) in sizes {
    for scale in scales {
        let pixels = Int(Double(size)! * Double(scale))
        let filename = "AppIcon-\(pixels).png"
        entries.append(["idiom": idiom, "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": filename])
        guard rendered.insert(pixels).inserted else { continue }
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let c = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                          bytesPerRow: pixels * 4, space: space,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        c.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        c.translateBy(x: 0, y: 1024); c.scaleBy(x: 1, y: -1)
        c.setFillColor(CGColor(srgbRed: 248/255, green: 249/255, blue: 245/255, alpha: 1))
        c.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        let green = CGColor(srgbRed: 0/255, green: 123/255, blue: 83/255, alpha: 1)
        c.setFillColor(green)
        let pin = CGMutablePath()
        pin.move(to: CGPoint(x: 480, y: 846))
        pin.addCurve(to: CGPoint(x: 448, y: 827), control1: CGPoint(x: 468, y: 846), control2: CGPoint(x: 458, y: 840))
        pin.addCurve(to: CGPoint(x: 218, y: 446), control1: CGPoint(x: 375, y: 732), control2: CGPoint(x: 218, y: 576))
        pin.addCurve(to: CGPoint(x: 480, y: 184), control1: CGPoint(x: 218, y: 301), control2: CGPoint(x: 335, y: 184))
        pin.addCurve(to: CGPoint(x: 742, y: 446), control1: CGPoint(x: 625, y: 184), control2: CGPoint(x: 742, y: 301))
        pin.addCurve(to: CGPoint(x: 512, y: 827), control1: CGPoint(x: 742, y: 576), control2: CGPoint(x: 585, y: 732))
        pin.addCurve(to: CGPoint(x: 480, y: 846), control1: CGPoint(x: 502, y: 840), control2: CGPoint(x: 492, y: 846))
        pin.closeSubpath(); c.addPath(pin); c.fillPath()
        c.setStrokeColor(green); c.setLineWidth(34); c.setLineCap(.round)
        c.move(to: CGPoint(x: 743, y: 202)); c.addLine(to: CGPoint(x: 773, y: 146))
        c.move(to: CGPoint(x: 795, y: 250)); c.addLine(to: CGPoint(x: 846, y: 220)); c.strokePath()
        c.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        c.addPath(CGPath(roundedRect: CGRect(x: 374, y: 328, width: 212, height: 150), cornerWidth: 43, cornerHeight: 43, transform: nil)); c.fillPath()
        c.addPath(CGPath(roundedRect: CGRect(x: 337, y: 501, width: 286, height: 72), cornerWidth: 36, cornerHeight: 36, transform: nil)); c.fillPath()
        c.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)); c.setLineWidth(34)
        c.move(to: CGPoint(x: 388, y: 553)); c.addLine(to: CGPoint(x: 373, y: 628))
        c.move(to: CGPoint(x: 572, y: 553)); c.addLine(to: CGPoint(x: 587, y: 628)); c.strokePath()
        let dest = CGImageDestinationCreateWithURL(output.appendingPathComponent(filename) as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, c.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(dest), "Could not write icon")
    }
}
let manifest: [String: Any] = ["images": entries, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("Contents.json"))
print("Generated \(rendered.count) opaque icon sizes for iPhone, iPad and App Store.")
