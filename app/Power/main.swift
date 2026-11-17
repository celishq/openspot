import Foundation

let holds = PowerHolds()
let listener = NSXPCListener(machServiceName: PowerDaemon.label)
listener.setConnectionCodeSigningRequirement(PowerDaemon.app)
listener.delegate = holds
signal(SIGTERM, SIG_IGN)
let stop = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .global())
stop.setEventHandler { holds.stop() }
stop.resume()
holds.start()
listener.resume()
dispatchMain()
