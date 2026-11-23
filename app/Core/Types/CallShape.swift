import Foundation

struct CallShape: Equatable, Sendable {
    let name: String
    let inputs: [Manifest.Parameter]
    let outputs: [Manifest.Parameter]
    let isLoose: Bool

    init(name: String, inputs: [Manifest.Parameter] = [], outputs: [Manifest.Parameter] = [], isLoose: Bool = false) {
        self.name = name
        self.inputs = inputs
        self.outputs = outputs
        self.isLoose = isLoose
    }

    static func all(of spot: Spot, bound: [String: Spot]) -> [CallShape] {
        var shapes = spot.actions.map { CallShape(name: $0.id, inputs: $0.inputs, outputs: $0.outputs) }
        let actions = Set(shapes.map(\.name))
        for handler in spot.triggers.handlers.sorted(by: { $0.name < $1.name }) where !actions.contains(handler.name) {
            shapes.append(CallShape(name: handler.name, inputs: handler.inputs))
        }
        for heard in spot.triggers.bindings {
            let event = bound[heard.binding]?.events.first { $0.name == heard.event }
            shapes.append(CallShape(name: heard.key, inputs: event?.values ?? [], isLoose: event == nil))
        }
        return shapes
    }
}
