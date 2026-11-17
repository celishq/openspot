import Foundation
import OpenspotCore
import os
import ServiceManagement

struct SpotPower: MacPower {
    private typealias Send<Answer: Sendable> = @Sendable (PowerService, @escaping @Sendable (Result<Answer, Error>) -> Void) -> Void

    private static let loginItems = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
    private static let stopped = "The power helper of Openspot stopped, so the Mac can sleep with its lid closed again. Start the hold again."
    private static let noAnswer = "The power helper of Openspot did not answer. Run the call again, or restart the Mac if it keeps failing."

    func holdLidClosed(during hold: @escaping @Sendable () async -> Void) async throws {
        let (fault, connection): (String?, NSXPCConnection) = try await Self.ask { service, reply in service.holdLidClosed { reply(.success($0)) } }
        guard fault == nil else {
            connection.invalidate()
            throw SpotError.fault(fault ?? Self.noAnswer)
        }
        let isLost = OSAllocatedUnfairLock(initialState: false)
        let held = Task { await hold() }
        let lose: @Sendable () -> Void = {
            isLost.withLock { $0 = true }
            held.cancel()
        }
        connection.interruptionHandler = lose
        connection.invalidationHandler = lose
        await withTaskCancellationHandler { await held.value } onCancel: { held.cancel() }
        let wasLost = isLost.withLock { $0 }
        connection.invalidate()
        if wasLost { throw SpotError.fault(Self.stopped) }
    }

    func sample() async throws -> Data {
        let (answer, connection): ((Data?, String?), NSXPCConnection) = try await Self.ask { service, reply in service.sample { reply(.success(($0, $1))) } }
        connection.invalidate()
        guard let data = answer.0 else { throw SpotError.fault(answer.1 ?? "powermetrics did not give a sample.") }
        return data
    }

    private static func ask<Answer: Sendable>(_ send: @escaping Send<Answer>) async throws -> (Answer, NSXPCConnection) {
        do {
            return try await once(send)
        } catch {
            try ready()
            do {
                return try await once(send)
            } catch let error as SpotError {
                throw error
            } catch {
                throw SpotError.fault(noAnswer)
            }
        }
    }

    private static func once<Answer: Sendable>(_ send: @escaping Send<Answer>) async throws -> (Answer, NSXPCConnection) {
        let daemon = try daemon()
        let connection = NSXPCConnection(machServiceName: daemon.label, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: PowerService.self)
        connection.setCodeSigningRequirement(daemon.helperRequirement)
        connection.resume()
        do {
            let answer: Answer = try await withCheckedThrowingContinuation { continuation in
                let reply = PowerReply(continuation)
                let proxy = connection.remoteObjectProxyWithErrorHandler { reply.give(.failure($0)) }
                guard let service = proxy as? PowerService else {
                    return reply.give(.failure(SpotError.fault("Openspot cannot reach its power helper.")))
                }
                send(service, reply.give)
            }
            return (answer, connection)
        } catch {
            connection.invalidate()
            throw error
        }
    }

    private static func daemon() throws -> PowerDaemon {
        guard let daemon = PowerDaemon.readForApp() else {
            throw SpotError.fault("This build of Openspot is not signed by a team, so it cannot start its power helper. Use a release of Openspot.")
        }
        return daemon
    }

    private static func ready() throws {
        let daemon = SMAppService.daemon(plistName: try daemon().plist)
        if daemon.status == .notRegistered || daemon.status == .notFound {
            do {
                try daemon.register()
            } catch {
                guard daemon.status == .requiresApproval else {
                    throw SpotError.fault("Openspot could not add its power helper: \(error.localizedDescription). Quit Openspot, open it again, then try again.")
                }
            }
        }
        switch daemon.status {
        case .enabled:
            return
        case .requiresApproval:
            SMAppService.openSystemSettingsLoginItems()
            throw SpotError.failedWithFix(1, "Openspot needs your approval for its power helper. Turn on Openspot in Login Items & Extensions, then try again.", loginItems)
        default:
            throw SpotError.fault(noAnswer)
        }
    }
}
