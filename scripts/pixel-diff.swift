import AppKit

let before = URL(fileURLWithPath: CommandLine.arguments[1])
let after = URL(fileURLWithPath: CommandLine.arguments[2])
let marks = URL(fileURLWithPath: CommandLine.arguments[3])

struct Pixels {
    let width: Int
    let height: Int
    var bytes: [UInt8]

    init?(_ file: URL) {
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        width = image.width
        height = image.height
        bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }

    func write(to file: URL) {
        var copy = bytes
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: &copy, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let image = context.makeImage() else { return }
        let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        try? data?.write(to: file)
    }
}

let names = (FileManager.default.enumerator(atPath: before.path)?.allObjects as? [String] ?? []).filter { $0.hasSuffix(".png") }.sorted()
var differs = false
for name in names {
    guard let one = Pixels(before.appendingPathComponent(name)) else { continue }
    guard var other = Pixels(after.appendingPathComponent(name)) else {
        print("\(name): missing after")
        differs = true
        continue
    }
    guard one.width == other.width, one.height == other.height else {
        print("\(name): size \(one.width)x\(one.height) before, \(other.width)x\(other.height) after")
        differs = true
        continue
    }
    var count = 0
    var box = (minX: Int.max, minY: Int.max, maxX: -1, maxY: -1)
    for y in 0..<one.height {
        for x in 0..<one.width {
            let at = (y * one.width + x) * 4
            guard one.bytes[at..<at + 4] != other.bytes[at..<at + 4] else { continue }
            count += 1
            box = (min(box.minX, x), min(box.minY, y), max(box.maxX, x), max(box.maxY, y))
            other.bytes.replaceSubrange(at..<at + 4, with: [255, 0, 255, 255])
        }
    }
    if count == 0 {
        print("\(name): 0")
        continue
    }
    differs = true
    let mark = marks.appendingPathComponent(name)
    try? FileManager.default.createDirectory(at: mark.deletingLastPathComponent(), withIntermediateDirectories: true)
    other.write(to: mark)
    print("\(name): \(count) pixels in x \(box.minX)...\(box.maxX), y \(box.minY)...\(box.maxY), marked in \(mark.path)")
}
for name in (FileManager.default.enumerator(atPath: after.path)?.allObjects as? [String] ?? []).filter({ $0.hasSuffix(".png") && !names.contains($0) }).sorted() {
    print("\(name): missing before")
    differs = true
}
exit(differs ? 1 : 0)
