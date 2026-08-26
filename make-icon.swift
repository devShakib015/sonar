import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

let W = 1024
let ctx = CGContext(data: nil, width: W, height: W, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let w = CGFloat(W)
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r/255, green: g/255, blue: b/255, alpha: a)
}
let center = CGPoint(x: w/2, y: w/2)

// Squircle background with vertical gradient
let inset = w * 0.07
let rect = CGRect(x: inset, y: inset, width: w - 2*inset, height: w - 2*inset)
let path = CGPath(roundedRect: rect, cornerWidth: w*0.225, cornerHeight: w*0.225, transform: nil)
ctx.saveGState()
ctx.addPath(path); ctx.clip()
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [rgb(18, 52, 78), rgb(8, 20, 34)] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: w), end: CGPoint(x: 0, y: 0), options: [])

// Crosshair
ctx.setStrokeColor(rgb(120, 200, 220, 0.16)); ctx.setLineWidth(4)
ctx.move(to: CGPoint(x: rect.minX, y: center.y)); ctx.addLine(to: CGPoint(x: rect.maxX, y: center.y))
ctx.move(to: CGPoint(x: center.x, y: rect.minY)); ctx.addLine(to: CGPoint(x: center.x, y: rect.maxY))
ctx.strokePath()

// Concentric sonar rings
let radii: [CGFloat] = [140, 250, 360, 450]
let alphas: [CGFloat] = [0.95, 0.7, 0.5, 0.32]
for (r, a) in zip(radii, alphas) {
    ctx.setStrokeColor(rgb(53, 224, 200, a)); ctx.setLineWidth(9)
    ctx.addArc(center: center, radius: r, startAngle: 0, endAngle: .pi*2, clockwise: false)
    ctx.strokePath()
}

// Sweep wedge (radar beam)
ctx.saveGState()
let a0: CGFloat = .pi * 0.12, a1: CGFloat = .pi * 0.46
ctx.move(to: center)
ctx.addArc(center: center, radius: 452, startAngle: a0, endAngle: a1, clockwise: false)
ctx.closePath(); ctx.clip()
let sweep = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                       colors: [rgb(80, 245, 216, 0.55), rgb(80, 245, 216, 0)] as CFArray,
                       locations: [0, 1])!
let beamDir = CGPoint(x: center.x + cos((a0+a1)/2)*452, y: center.y + sin((a0+a1)/2)*452)
ctx.drawLinearGradient(sweep, start: center, end: beamDir, options: [])
ctx.restoreGState()

// Blip
let ba: CGFloat = .pi * 0.30, br: CGFloat = 250
let blip = CGPoint(x: center.x + cos(ba)*br, y: center.y + sin(ba)*br)
ctx.setFillColor(rgb(124, 245, 216, 0.28))
ctx.addArc(center: blip, radius: 52, startAngle: 0, endAngle: .pi*2, clockwise: false); ctx.fillPath()
ctx.setFillColor(rgb(150, 255, 224, 1))
ctx.addArc(center: blip, radius: 24, startAngle: 0, endAngle: .pi*2, clockwise: false); ctx.fillPath()

// Center dot
ctx.setFillColor(rgb(210, 255, 245, 1))
ctx.addArc(center: center, radius: 16, startAngle: 0, endAngle: .pi*2, clockwise: false); ctx.fillPath()
ctx.restoreGState()

let cg = ctx.makeImage()!
let url = URL(fileURLWithPath: "icon_1024.png") as CFURL
let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, cg, nil)
CGImageDestinationFinalize(dest)
print("icon_1024.png written")
