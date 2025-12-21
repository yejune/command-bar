import SwiftUI
import AppKit

extension NSImage {
    static func colorCircle(size: CGFloat, color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: NSSize(width: size, height: size))
        let path = NSBezierPath(ovalIn: rect)
        color.setFill()
        path.fill()

        image.unlockFocus()
        return image
    }
}

func colorCircleImage(_ colorName: String, size: CGFloat = 10) -> Image {
    let nsColor: NSColor
    switch colorName {
    case "blue": nsColor = .systemBlue
    case "red": nsColor = .systemRed
    case "green": nsColor = .systemGreen
    case "orange": nsColor = .systemOrange
    case "purple": nsColor = .systemPurple
    case "gray": nsColor = .systemGray
    default: nsColor = .systemGray
    }
    return Image(nsImage: NSImage.colorCircle(size: size, color: nsColor))
}
