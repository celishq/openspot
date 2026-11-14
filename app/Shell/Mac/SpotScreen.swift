import AppKit
import AVFoundation
import OpenspotCore
import ScreenCaptureKit
import UniformTypeIdentifiers

enum SpotScreen {
    static let screenRecording = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"

    static func sources() async -> String {
        var rows = await displays()
        for window in SpotScreenTarget.windows() {
            let owner = window[kCGWindowOwnerName as String] as? String ?? ""
            let title = (window[kCGWindowName as String] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? owner
            let id = window[kCGWindowNumber as String] as? UInt32 ?? 0
            let app = (window[kCGWindowOwnerPID as String] as? pid_t).flatMap { NSRunningApplication(processIdentifier: $0)?.bundleURL?.path }
            rows.append(row("window:\(id)", title, owner, icon: app ?? "macwindow"))
        }
        rows.append(row("system", "Sound of the Mac", "Sound", icon: "speaker.wave.2"))
        let microphones = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone], mediaType: .audio, position: .unspecified).devices
        rows += microphones.map { row("mic:\($0.uniqueID)", $0.localizedName, "Microphone", icon: "mic") }
        let cameras = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera], mediaType: .video, position: .unspecified).devices
        rows += cameras.map { row("camera:\($0.uniqueID)", $0.localizedName, "Camera", icon: "camera") }
        return rows.map { $0.text + "\n" }.joined()
    }

    @MainActor
    private static func displays() -> [TextBlock] {
        NSScreen.screens.compactMap { screen in
            guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { return nil }
            let size = "\(Int(screen.frame.width))×\(Int(screen.frame.height))"
            return row("display:\(id)", screen.localizedName, "Display · \(size)", icon: "display")
        }
    }

    static func shot(_ capture: ScreenCapture, in folder: URL) async throws -> String {
        guard let found = try await SpotScreenTarget.target(of: capture.source), !Task.isCancelled else { return "" }
        let file = try CaptureFile(path: capture.file, kind: .picture, folder: screenshots, current: folder).url
        let (image, scale) = try await picture(of: found, cursor: capture.cursor)
        try write(image, scale: scale, to: file)
        return file.path + "\n"
    }

    private static func picture(of found: ScreenTarget, cursor: Bool) async throws -> (CGImage, CGFloat) {
        let target = try await SpotScreenTarget.find(found)
        let image = try await allowed { try await SCScreenshotManager.captureImage(contentFilter: target.filter, configuration: target.configuration(cursor: cursor)) }
        return (image, target.scale)
    }

    static func allowed<Value>(isolation: isolated (any Actor)? = #isolation, _ work: () async throws -> Value) async throws -> Value {
        do {
            return try await work()
        } catch {
            guard !CGPreflightScreenCaptureAccess() else { throw error }
            CGRequestScreenCaptureAccess()
            throw SpotError.failedWithFix(1, "Openspot cannot see the screen. Allow Openspot in Screen Recording, then try again.", URL(string: screenRecording)!)
        }
    }

    static var screenshots: URL {
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
        guard let location = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") else { return desktop }
        let folder = URL(fileURLWithPath: (location as NSString).expandingTildeInPath, isDirectory: true)
        var isFolder: ObjCBool = false
        return FileManager.default.fileExists(atPath: folder.path, isDirectory: &isFolder) && isFolder.boolValue ? folder : desktop
    }

    private static func row(_ id: String, _ title: String, _ detail: String, icon: String) -> TextBlock {
        TextBlock(fields: [.init(key: "row", value: id), .init(key: "title", value: title), .init(key: "detail", value: detail), .init(key: "icon", value: icon)])
    }

    private static func write(_ image: CGImage, scale: CGFloat, to url: URL) throws {
        let type: UTType = switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": .jpeg
        case "heic": .heic
        default: .png
        }
        let folder = url.deletingLastPathComponent()
        let partial = folder.appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString.prefix(8))")
        let properties = [kCGImagePropertyDPIWidth: 72 * scale, kCGImagePropertyDPIHeight: 72 * scale] as CFDictionary
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let destination = CGImageDestinationCreateWithURL(partial as CFURL, type.identifier as CFString, 1, nil) else {
            throw SpotError.fault("Openspot cannot write to \(folder.path). Name a file in a folder that you can write to.")
        }
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination), rename(partial.path, url.path) == 0 else {
            try? FileManager.default.removeItem(at: partial)
            throw SpotError.fault("Openspot cannot write to \(folder.path). Name a file in a folder that you can write to.")
        }
    }
}
