import CoreGraphics
import Foundation

extension BoxLayout {
    static func pinned(_ child: Child, in size: CGSize) -> CGRect {
        let pins = child.style.pins
        let width = pins.isSuperset(of: [.left, .right])
            ? size.width
            : clamped(points(child.style.width, of: size.width) ?? min(child.measure(nil, nil).width, size.width), child.style, of: size.width)
        let height = pins.isSuperset(of: [.top, .bottom])
            ? size.height
            : points(child.style.height, of: size.height) ?? (child.style.isSquare ? width : child.measure(width, nil).height)
        let x = pins.contains(.right) && !pins.contains(.left) ? size.width - width : 0
        let y = pins.contains(.bottom) && !pins.contains(.top) ? size.height - height : 0
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
