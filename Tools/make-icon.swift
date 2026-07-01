// Renders the Macmd app icon (1024×1024 PNG) with CoreGraphics.
// Usage: swift Tools/make-icon.swift  ->  Icon/icon-1024.png
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let S = 1024.0
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8,
                    bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
func c(_ r: Double,_ g: Double,_ b: Double,_ a: Double = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat(r),CGFloat(g),CGFloat(b),CGFloat(a)])!
}
func rr(_ x: Double,_ y: Double,_ w: Double,_ h: Double,_ r: Double) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
}

// rounded-square background with a diagonal blue gradient
let inset = 96.0
let sq = rr(inset, inset, S-2*inset, S-2*inset, 190)
ctx.saveGState()
ctx.addPath(sq); ctx.clip()
let bg = CGGradient(colorsSpace: cs, colors: [c(0.31,0.51,0.97), c(0.13,0.27,0.80)] as CFArray, locations: [0,1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: inset, y: S-inset), end: CGPoint(x: S-inset, y: inset), options: [])
let sheen = CGGradient(colorsSpace: cs, colors: [c(1,1,1,0.22), c(1,1,1,0)] as CFArray, locations: [0,1])!
ctx.drawLinearGradient(sheen, start: CGPoint(x: 0, y: S-inset), end: CGPoint(x: 0, y: S*0.52), options: [])
ctx.restoreGState()

// two panels (dual-pane) with a soft drop shadow
let lMargin = 150.0, gap = 30.0
let regionX = inset + lMargin
let regionW = S - 2*(inset + lMargin)
let panelW = (regionW - gap)/2
let topMargin = 180.0, botMargin = 150.0
let panelY = inset + botMargin
let panelH = (S - inset - topMargin) - panelY
let leftX = regionX
let rightX = regionX + panelW + gap
let pr = 34.0

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -20), blur: 46, color: c(0,0,0,0.30))
ctx.setFillColor(c(1,1,1,0.97))
ctx.addPath(rr(leftX, panelY, panelW, panelH, pr)); ctx.fillPath()
ctx.addPath(rr(rightX, panelY, panelW, panelH, pr)); ctx.fillPath()
ctx.restoreGState()

func drawPanel(_ x: Double, active: Bool) {
    ctx.saveGState()
    ctx.addPath(rr(x, panelY, panelW, panelH, pr)); ctx.clip()
    let hH = 84.0
    ctx.setFillColor(active ? c(0.86,0.90,0.99) : c(0.92,0.93,0.95))
    ctx.fill(CGRect(x: x, y: panelY + panelH - hH, width: panelW, height: hH))
    let dotY = panelY + panelH - hH/2 - 9
    let dots = [c(0.98,0.45,0.42), c(0.98,0.75,0.30), c(0.42,0.80,0.42)]
    for (i, dc) in dots.enumerated() {
        ctx.setFillColor(dc)
        ctx.fillEllipse(in: CGRect(x: x + 28 + Double(i)*34, y: dotY, width: 18, height: 18))
    }
    let rowPad = 30.0
    let rowX = x + rowPad
    let rowW = panelW - 2*rowPad
    let rowH = 30.0, step = 52.0
    let widths = [0.9, 1.0, 0.75, 0.95, 0.6]
    var ry = panelY + panelH - hH - 60.0
    for (i, wf) in widths.enumerated() {
        let highlight = active && i == 1
        ctx.setFillColor(highlight ? c(1.0,0.60,0.10) : c(0.80,0.83,0.89))
        ctx.addPath(rr(rowX, ry, rowW*wf, rowH, rowH/2)); ctx.fillPath()
        ry -= step
    }
    ctx.restoreGState()
}
drawPanel(leftX, active: true)
drawPanel(rightX, active: false)

let img = ctx.makeImage()!
let out = URL(fileURLWithPath: "Icon/icon-1024.png")
try? FileManager.default.createDirectory(at: URL(fileURLWithPath: "Icon"), withIntermediateDirectories: true)
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("wrote", out.path)
