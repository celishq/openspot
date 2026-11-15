import AppKit
import AVFoundation
import OpenspotCore
import ScreenCaptureKit
import UniformTypeIdentifiers

struct SpotScreen: MacScreen {
    static let screenRecording = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"

    func devices() async -> [ScreenDevice] {
        var devices = await Self.displays()
        for window in SpotScreenTarget.windows() {
            let owner = window[kCGWindowOwnerName as String] as? String ?? ""
            let title = (window[kCGWindowName as String] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? owner
            let id = window[kCGWindowNumber as String] as? UInt32 ?? 0
            let app = (window[kCGWindowOwnerPID as String] as? pid_t).flatMap { NSRunningApplication(processIdentifier: $0)?.bundleURL?.path }
            devices.append(ScreenDevice(kind: .window, id: String(id), name: title, detail: owner, app: app))
        }
        let microphones = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone], mediaType: .audio, position: .unspecified).devices
        devices += microphones.map { ScreenDevice(kind: .mic, id: $0.uniqueID, name: $0.localizedName) }
        let cameras = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera], mediaType: .video, position: .unspecified).devices
        return devices + cameras.map { ScreenDevice(kind: .camera, id: $0.uniqueID, name: $0.localizedName) }
    }

    @MainActor
    private static func displays() -> [ScreenDevice] {
        NSScreen.screens.compactMap { screen in
            guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { return nil }
            return ScreenDevice(kind: .display, id: String(id), name: screen.localizedName, detail: "\(Int(screen.frame.width))×\(Int(screen.frame.height))")
        }
    }

    func shot(_ capture: ScreenCapture, in folder: URL) async throws -> URL? {
        guard let found = try await SpotScreenTarget.target(of: capture.source), !Task.isCancelled else { return nil }
        let file = try CaptureFile(path: capture.file, kind: .picture, folder: Self.screenshots, current: folder).url
        let (image, scale) = try await Self.picture(of: found, cursor: capture.cursor)
        try Self.write(image, scale: scale, to: file)
        return file
    }

    func startRecording(_ capture: ScreenCapture, in folder: URL) async throws {
        try await SpotRecording.start(capture, in: folder)
    }

    func stopRecording() async throws -> ScreenRecording {
        try await SpotBlocking.run { try SpotRecording.stop() }
    }

    func recording() async throws -> ScreenRecording? {
        try await SpotBlocking.run { try SpotRecording.status() }
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
