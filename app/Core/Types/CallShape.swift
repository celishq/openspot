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
        let text = ValueType(.text)
        var shapes = spot.typedActions.map { CallShape(name: $0.id, inputs: $0.inputs, outputs: $0.outputs) }
        let names = Manifest.Triggers.named.union(spot.triggers?.handlers ?? []).subtracting(shapes.map(\.name)).sorted()
        for name in names {
            let inputs: [Manifest.Parameter] = switch name {
            case Manifest.Triggers.command: [.init(name: "name", type: text), .init(name: "text", type: text)]
            case Manifest.Triggers.search: [.init(name: "text", type: text)]
            case Message.pressHandler: [.init(name: "item", type: text)]
            case "drag": [.init(name: "item", type: ValueType(.text, isList: true))]
            case Manifest.Triggers.drop: [.init(name: "file", type: ValueType(.file, isList: true))]
            case Manifest.Triggers.schedule: [.init(name: "cron", type: text), .init(name: "late", type: ValueType(.duration))]
            case _ where SpotEvent.known.contains(name): [.init(name: "value", type: text, isRequired: false)]
            default: []
            }
            shapes.append(CallShape(name: name, inputs: inputs))
        }
        for key in spot.triggers?.bindings ?? [] {
            let event = bound[Manifest.Triggers.binding(of: key)]?.events.first { $0.name == Manifest.Triggers.event(of: key) }
            shapes.append(CallShape(name: key, inputs: event?.values ?? [], isLoose: event == nil))
        }
        return shapes
    }
}
