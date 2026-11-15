import OpenspotCore
import SwiftUI

struct SheetStep {
    struct Leaving {
        let look: AnyView
        let from: CGRect
        let rect: CGRect
    }

    var marks: [FlowEdge] = []
    var room: CGRect?
    var fit: CGRect?
    var leaving: Leaving?
    var field: AnyView?
}
