import Cocoa

// Renders a 1024x1024 app icon: a dark squircle with a white cursor + motion
// lines symbol. Output path is argv[1].

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let size: CGFloat = 1024

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no context") }

// --- Background squircle -----------------------------------------------------
let margin: CGFloat = 90
let rect = CGRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
let radius = rect.width * 0.235
let clip = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
clip.addClip()

let colors = [
    NSColor(calibratedRed: 0.13, green: 0.13, blue: 0.14, alpha: 1).cgColor, // near-black top
    NSColor(calibratedRed: 0.24, green: 0.25, blue: 0.27, alpha: 1).cgColor, // dark gray bottom
] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: rect.midX, y: rect.maxY),
                       end: CGPoint(x: rect.midX, y: rect.minY),
                       options: [])

// Subtle top highlight for depth.
NSColor(calibratedWhite: 1, alpha: 0.06).setFill()
NSBezierPath(roundedRect: rect.insetBy(dx: 0, dy: rect.height * 0.5),
             xRadius: radius, yRadius: radius).fill()

// --- Foreground symbol -------------------------------------------------------
let config = NSImage.SymbolConfiguration(pointSize: 430, weight: .semibold)
if let base = NSImage(systemSymbolName: "slider.horizontal.3",
                      accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {

    // Tint the template symbol white.
    let symSize = base.size
    let white = NSImage(size: symSize)
    white.lockFocus()
    base.draw(at: .zero, from: NSRect(origin: .zero, size: symSize),
              operation: .sourceOver, fraction: 1)
    NSColor.white.setFill()
    NSRect(origin: .zero, size: symSize).fill(using: .sourceAtop)
    white.unlockFocus()

    let drawRect = CGRect(x: (size - symSize.width) / 2,
                          y: (size - symSize.height) / 2,
                          width: symSize.width, height: symSize.height)
    white.draw(in: drawRect, from: NSRect(origin: .zero, size: symSize),
               operation: .sourceOver, fraction: 0.97)
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("failed to encode PNG")
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
