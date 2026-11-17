import Foundation

guard let daemon = PowerDaemon.readForHelper() else { exit(1) }
let holds = PowerHolds()
let listener = NSXPCListener(machServiceName: daemon.label)
listener.setConnectionCodeSigningRequirement(daemon.appRequirement)
listener.delegate = holds
signal(SIGTERM, SIG_IGN)
let stop = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .global())
stop.setEventHandler { holds.stop() }
stop.resume()
holds.start()
listener.resume()
dispatchMain()
