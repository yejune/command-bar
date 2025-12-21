import SwiftUI
import AppKit

extension NSImage {
    static func colorCircle(size: CGFloat, color: NSColor, leftShift: CGFloat = 0) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: NSSize(width: size, height: size))
        let path = NSBezierPath(ovalIn: rect)
        color.setFill()
        path.fill()

        image.unlockFocus()

        // alignmentRect로 왼쪽으로 이동
        if leftShift != 0 {
            image.alignmentRect = NSRect(x: leftShift, y: 0, width: size, height: size)
        }
        return image
    }
}

func colorCircleImage(_ colorName: String, size: CGFloat = 10, leftShift: CGFloat = 0) -> Image {
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
    return Image(nsImage: NSImage.colorCircle(size: size, color: nsColor, leftShift: leftShift))
}
