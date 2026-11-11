import AppKit
import AVFoundation
import OpenspotCore

/// `openspot screen record`: the command finds the source and asks for the mic and the camera, and the `screen` helper keeps
/// one recording until a stop, after the call that started it ends (S10).
@MainActor
enum SpotRecording {
    nonisolated static let capability = Capability(name: "screen")
    nonisolated private static let microphonePane = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
    nonisolated private static let cameraPane = "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
    private static var session: SpotRecordingSession?

    /// Starts a recording of the source, and returns nothing. A cancel of the pick starts none. A relative file starts in
    /// `folder`. It runs on the thread of its call, apart from the pick.
    nonisolated static func start(_ capture: ScreenCapture, in folder: URL) async throws -> String {
        guard let target = try await SpotScreenTarget.target(of: capture.source) else { return "" }
        let file = try CaptureFile(path: capture.file, kind: .video, folder: SpotScreen.screenshots, current: folder).url
        var camera: String?
        for input in capture.inputs {
            switch input {
            case .system: break
            case .mic: try await allow(.audio, "Openspot cannot hear the microphone. Allow Openspot in Microphone, then try again.", microphonePane)
            case .camera:
                try await allow(.video, "Openspot cannot see the camera. Allow Openspot in Camera, then try again.", cameraPane)
                camera = CaptureFile.camera(beside: file).path
            }
        }
        let events = capture.events.map { $0.hasPrefix("/") ? $0 : folder.appendingPathComponent($0).path }
        guard !Task.isCancelled else { return "" }
        let plan = RecordingRequest.Plan(target: target, inputs: capture.inputs, cursor: capture.cursor, file: file.path, camera: camera, events: events)
        _ = try await SpotBlocking.run { try ask(.start(plan)) }
        return ""
    }

    /// Ends the recording, and returns each file on a line, the video first.
    nonisolated static func stop() throws -> String {
        let block = try ask(.stop)
        return ["file", "camera", "events"].compactMap { block.value($0) }.map { $0 + "\n" }.joined()
    }

    nonisolated static func status() throws -> String {
        try ask(.status).text
    }

    /// Runs as the helper: answers each request, and stays while a recording runs. It runs the event loop of the app on
    /// the main thread, where ScreenCaptureKit draws its mark of a recording in the menu bar.
    static func serve() -> Never {
        let app = NSApplication.shared
        capability.serve(isBusy: { await SpotRecording.session != nil }, runMain: { MainActor.assumeIsolated { app.run() }; exit(0) }) { request in
            await SpotRecording.answer(to: String(decoding: request, as: UTF8.self))
        }
    }

    /// Sends a request to the helper, and turns an answer with a fault into a failure with its fix.
    nonisolated private static func ask(_ request: RecordingRequest) throws -> TextBlock {
        let answer = String(decoding: try capability.call(Data(request.text.utf8)), as: UTF8.self)
        let block = TextBlock.blocks(in: answer).first ?? TextBlock(fields: [])
        guard let fault = block.value("fault") else { return block }
        if let link = block.value("link").flatMap(URL.init(string:)) { throw SpotError.failedWithFix(1, fault, link) }
        throw SpotError.fault(fault)
    }

    /// Asks macOS for a device when the person has not answered yet, and fails with the fix when it is not allowed.
    nonisolated private static func allow(_ media: AVMediaType, _ fault: String, _ pane: String) async throws {
        guard AVCaptureDevice.authorizationStatus(for: media) != .authorized else { return }
        guard await AVCaptureDevice.requestAccess(for: media) else { throw SpotError.failedWithFix(1, fault, URL(string: pane)!) }
    }

    private static func answer(to text: String) async -> Data {
        let block: TextBlock
        do {
            block = try await respond(to: RecordingRequest(text: text))
        } catch let SpotError.failedWithFix(_, fault, link) {
            block = TextBlock(fields: [.init(key: "fault", value: fault), .init(key: "link", value: link.absoluteString)])
        } catch {
            block = TextBlock(fields: [.init(key: "fault", value: (error as? SpotError)?.reason ?? error.localizedDescription)])
        }
        return Data(block.text.utf8)
    }

    private static func respond(to request: RecordingRequest?) async throws -> TextBlock {
        switch request {
        case .start(let plan)?:
            if let session {
                let name = URL(fileURLWithPath: session.status.value("file") ?? "").lastPathComponent
                throw SpotError.fault("Openspot is already recording to \(name). Run `openspot screen record stop` first.")
            }
            session = try await SpotRecordingSession.start(plan)
            return TextBlock(fields: [.init(key: "state", value: "recording")])
        case .stop?:
            guard let running = session else {
                throw SpotError.fault("Openspot is not recording. Start a recording with `openspot screen record start`.")
            }
            session = nil
            return try await running.stop()
        case .status?:
            return session?.status ?? TextBlock(fields: [.init(key: "state", value: "idle")])
        case nil:
            throw SpotError.fault("The recording helper cannot read this call. Run the command again.")
        }
    }
}
