import Foundation

let holds = PowerHolds()
let listener = NSXPCListener(machServiceName: PowerDaemon.label)
listener.setConnectionCodeSigningRequirement(PowerDaemon.app)
listener.delegate = holds
holds.start()
listener.resume()
dispatchMain()
