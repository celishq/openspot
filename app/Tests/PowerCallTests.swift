import XCTest
@testable import OpenspotCore

final class PowerCallTests: XCTestCase {
    private final class Acts: @unchecked Sendable {
        private let lock = NSLock()
        private var kept: [String] = []

        var all: [String] { lock.withLock { kept } }

        func keep(_ act: String) {
            lock.withLock { kept.append(act) }
        }
    }

    private struct Power: MacPower {
        let acts: Acts
        var fault: String?

        func holdLidClosed(during hold: @escaping @Sendable () async -> Void) async throws {
            if let fault { throw SpotError.fault(fault) }
            acts.keep("hold")
            await hold()
            acts.keep("release")
        }

        func sample() async throws -> Data {
            if let fault { throw SpotError.fault(fault) }
            let sample: [String: Any] = [
                "processor": ["cpu_power": 1234.0, "gpu_power": 56.4, "ane_power": 0.0, "combined_power": 1290.4],
                "thermal_pressure": "Nominal"
            ]
            return try PropertyListSerialization.data(fromPropertyList: sample, format: .xml, options: 0) + Data([0])
        }
    }

    private var client: TestClient!
    private var socket: CommandSocket?
    private let acts = Acts()

    override func setUpWithError() throws {
        client = try TestClient(beside: Bundle(for: Self.self))
    }

    override func tearDownWithError() throws {
        socket?.close()
        client.remove()
    }

    private func serve(fault: String? = nil) {
        socket = CommandSocket(folder: client.config, api: CommandAPI(mac: Mac(power: Power(acts: acts, fault: fault)), places: .test(["OPENSPOT_CONFIG": client.config.path]), rates: .offline))
    }

    private func run(_ arguments: [String]) throws -> (output: String, errors: String, code: Int32) {
        try client.run(arguments)
    }

    func testLidClosedHoldsWhileTheCallRunsAndLetsGoWhenItEnds() async throws {
        serve()
        let call = try client.start(["power", "lid-closed"])
        defer { if call.process.isRunning { call.process.terminate() } }

        let first = String(decoding: call.output.fileHandleForReading.availableData, as: UTF8.self)

        XCTAssertEqual(first, "on\n")
        XCTAssertEqual(acts.all, ["hold"])
        call.process.terminate()
        try await wait("the hold is let go") { acts.all == ["hold", "release"] }
    }

    func testLidClosedFailsWithTheLineOfTheHelperWhenItCannotHold() throws {
        serve(fault: "Allow Openspot in Login Items.")

        let answer = try run(["power", "lid-closed"])

        XCTAssertEqual(answer.code, 1)
        XCTAssertEqual(answer.output, "")
        XCTAssertEqual(answer.errors, "Allow Openspot in Login Items.\n")
        XCTAssertEqual(acts.all, [])
    }

    func testReadingsPrintTheWattsAndTheThermalPressureOfOneSample() throws {
        serve()

        let answer = try run(["power", "readings"])

        XCTAssertEqual(answer.output, "watts=1.29\ncpu-watts=1.23\ngpu-watts=0.06\nane-watts=0.00\nthermal-pressure=nominal\n")
        XCTAssertEqual(answer.code, 0)
    }

    func testReadingsPrintJSONWithTheSameFields() throws {
        serve()

        let answer = try run(["power", "readings", "--json"])

        XCTAssertEqual(answer.output, "{\"ane-watts\":0,\"cpu-watts\":1.234,\"gpu-watts\":0.0564,\"thermal-pressure\":\"nominal\",\"watts\":1.2904}\n")
    }
}
