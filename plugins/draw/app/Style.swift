import Foundation

/// The look that the next figure takes, and that a pick gives to the selected ones.
struct Style: Equatable {
    var ink = Figure.Ink.black
    var weight = Figure.Weight.m
    var dashed = false
    var filled = false
    var heads = Figure.Heads.end

    /// The style of a figure.
    init(of figure: Figure) {
        ink = figure.ink
        weight = figure.weight
        dashed = figure.dashed
        filled = figure.filled
        if figure.kind == .arrow { heads = figure.heads }
    }

    init() {}

    func dress(_ figure: inout Figure) {
        figure.ink = ink
        figure.weight = weight
        figure.dashed = dashed
        figure.filled = filled
        if figure.kind == .arrow { figure.heads = heads }
    }
}
