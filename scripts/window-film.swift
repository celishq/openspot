import AppKit
import CoreImage
import Foundation
import ScreenCaptureKit

/// Films the largest window of one process for some seconds, and writes each frame that changed as a PNG named by its
/// time in milliseconds. It records only that window, so nothing else on the screen lands in the files.
final class WindowFilm: NSObject, SCStreamOutput {
    let folder: URL
    private var start: Double?
    private let context = CIContext()
    private(set) var count = 0

    init(folder: URL) {
        self.folder = folder
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard let info = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              (info.first?[.status] as? Int).flatMap(SCFrameStatus.init) == .complete,
              let pixels = CMSampleBufferGetImageBuffer(buffer) else { return }
        let time = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(buffer))
        let first = start ?? time
        start = first
        let url = folder.appendingPathComponent(String(format: "%06d.png", Int((time - first) * 1000)))
        try? context.writePNGRepresentation(of: CIImage(cvPixelBuffer: pixels), to: url, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        count += 1
    }
}

let arguments = CommandLine.arguments
guard arguments.count == 4, let seconds = Double(arguments[2]), let pid = pid_t(arguments[3]) else {
    print("usage: window-film <folder> <seconds> <pid>")
    exit(2)
}
let film = WindowFilm(folder: URL(fileURLWithPath: arguments[1]))
Task {
    do {
        var window: SCWindow?
        for _ in 0..<200 where window == nil {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            window = content.windows.filter { $0.owningApplication?.processID == pid && $0.frame.width > 300 }
                .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
            if window == nil { try await Task.sleep(for: .milliseconds(50)) }
        }
        guard let window else {
            print("no window")
            exit(1)
        }
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width * 2)
        config.height = Int(window.frame.height * 2)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 120)
        config.showsCursor = false
        config.queueDepth = 8
        let stream = SCStream(filter: SCContentFilter(desktopIndependentWindow: window), configuration: config, delegate: nil)
        try stream.addStreamOutput(film, type: .screen, sampleHandlerQueue: DispatchQueue(label: "film"))
        try await stream.startCapture()
        try await Task.sleep(for: .seconds(seconds))
        try await stream.stopCapture()
        print("frames \(film.count)")
        exit(0)
    } catch {
        print("film failed: \(error)")
        exit(1)
    }
}
RunLoop.main.run()
