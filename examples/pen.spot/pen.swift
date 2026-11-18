#!/usr/bin/env swift

// Openspot builds this file with the Swift files of `pen/`. The call that opens the overlay stays open while it shows,
// so its card shows it running and a quit of Openspot closes it. A second press, of the card or of the key, closes it.
import AppKit

var overlay: Overlay?
var drawing: String?

/// Closes the overlay and ends the call that opened it.
func close() {
    overlay?.close()
    overlay = nil
    if let drawing { Link.end(drawing) }
    drawing = nil
}

Link.listen { call in
    Link.start(call.id)
    switch call.arguments.first {
    case "draw", "open":
        guard overlay == nil else {
            close()
            return Link.end(call.id)
        }
        drawing = call.id
        overlay = Overlay {
            overlay = nil
            close()
        }
        overlay?.show()
    default: Link.end(call.id)
    }
} stop: { id in
    if id == drawing { close() }
} end: {
    exit(0)
}
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()
