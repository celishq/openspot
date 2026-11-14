import AVFoundation
import OpenspotCore
import ScreenCaptureKit

@MainActor
final class SpotRecordingSession {
    private static let h264Limit = CGSize(width: 4096, height: 2304)

    private let plan: RecordingRequest.Plan
    private let stream: SCStream
    private let output: SCRecordingOutput
    private let videoEnd: SpotFileEnd
    private let camera: (session: AVCaptureSession, movie: AVCaptureMovieFileOutput, end: SpotFileEnd)?
    private let events: SpotEventLog?
    private let started = Date()

    private init(plan: RecordingRequest.Plan, stream: SCStream, output: SCRecordingOutput, videoEnd: SpotFileEnd, camera: (AVCaptureSession, AVCaptureMovieFileOutput, SpotFileEnd)?, events: SpotEventLog?) {
        self.plan = plan
        self.stream = stream
        self.output = output
        self.videoEnd = videoEnd
        self.camera = camera
        self.events = events
    }

    static func start(_ plan: RecordingRequest.Plan) async throws -> SpotRecordingSession {
        let target = try await SpotScreenTarget.find(plan.target)
        let file = URL(fileURLWithPath: plan.file)
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: file)
        let configuration = target.configuration(cursor: plan.cursor)
        configuration.width -= configuration.width % 2
        configuration.height -= configuration.height % 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        for input in plan.inputs {
            switch input {
            case .system:
                configuration.capturesAudio = true
                configuration.excludesCurrentProcessAudio = true
            case .mic(let id):
                configuration.captureMicrophone = true
                configuration.microphoneCaptureDeviceID = id
            case .camera: break
            }
        }
        let recording = SCRecordingOutputConfiguration()
        recording.outputURL = file
        recording.outputFileType = file.pathExtension.lowercased() == "mov" ? .mov : .mp4
        let fits = CGFloat(configuration.width) <= h264Limit.width && CGFloat(configuration.height) <= h264Limit.height
        recording.videoCodecType = fits ? .h264 : .hevc
        let camera = try plan.camera.map { try cameraParts(plan.inputs, to: $0) }
        let events = try plan.events.map { try SpotEventLog(path: $0, frame: target.frame, scale: target.scale) }
        let stream = SCStream(filter: target.filter, configuration: configuration, delegate: nil)
        let end = SpotFileEnd()
        let output = SCRecordingOutput(configuration: recording, delegate: end)
        do {
            try stream.addRecordingOutput(output)
            try await SpotScreen.allowed { try await stream.startCapture() }
        } catch {
            events?.stop()
            throw error
        }
        let session = SpotRecordingSession(plan: plan, stream: stream, output: output, videoEnd: end, camera: camera, events: events)
        if let camera {
            camera.0.startRunning()
            camera.1.startRecording(to: URL(fileURLWithPath: plan.camera!), recordingDelegate: camera.2)
        }
        do {
            try events?.listen()
        } catch {
            _ = try? await session.stop()
            throw error
        }
        return session
    }

    var status: TextBlock {
        TextBlock(fields: [.init(key: "state", value: "recording")] + files + [.init(key: "seconds", value: String(Int(Date().timeIntervalSince(started))))])
    }

    func stop() async throws -> TextBlock {
        events?.stop()
        try? await stream.stopCapture()
        var failure: Error?
        do { try await videoEnd.wait() } catch { failure = error }
        if let camera {
            camera.movie.stopRecording()
            do { try await camera.end.wait() } catch { failure = failure ?? error }
            camera.session.stopRunning()
        }
        if let failure { throw SpotError.fault("The recording stopped with a fault: \(failure.localizedDescription) What it wrote is in \(plan.file).") }
        return TextBlock(fields: files)
    }

    private var files: [TextBlock.Field] {
        [("file", plan.file), ("camera", plan.camera), ("events", plan.events)].compactMap { key, value in value.map { .init(key: key, value: $0) } }
    }

    private static func cameraParts(_ inputs: [ScreenInput], to path: String) throws -> (AVCaptureSession, AVCaptureMovieFileOutput, SpotFileEnd) {
        let id = inputs.lazy.compactMap { input -> String?? in
            if case .camera(let id) = input { return .some(id) }
            return nil
        }.first ?? nil
        guard let device = id.flatMap(AVCaptureDevice.init(uniqueID:)) ?? (id == nil ? AVCaptureDevice.default(for: .video) : nil) else {
            throw SpotError.fault("Openspot cannot find the camera \(id ?? ""). Run `openspot screen sources` to see each camera.")
        }
        let session = AVCaptureSession()
        let movie = AVCaptureMovieFileOutput()
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input), session.canAddOutput(movie) else {
            throw SpotError.fault("Openspot cannot record \(device.localizedName). Close the app that uses it, then try again.")
        }
        session.addInput(input)
        session.addOutput(movie)
        try? FileManager.default.removeItem(atPath: path)
        return (session, movie, SpotFileEnd())
    }
}
