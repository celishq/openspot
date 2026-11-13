import Foundation

/// The reads of a run, the searches of its list and the answers to a text of the main search.
extension SpotRun {
    /// Asks for the first answer, and runs the given work when it arrives.
    public func afterAnswer(_ work: @escaping () -> Void) {
        waiter = work
        read()
    }

    /// Asks the script for what it shows. A list that the script searches sends the text that is typed on stdin, so that the answer
    /// gives the spot's new value and the rows of that text. A request joins the read that runs, and a change reads again
    /// after it (protocol: Events). A `panel` or a `sheet` moment uses an answer younger than 5 seconds (M2). A file with no `read` gets
    /// its click instead.
    public func read(selecting run: String? = nil, need: ReadNeed = .moment, reason: ReadReason? = nil) {
        let reason = reason ?? (need == .change ? .change : showsSheet ? .sheet : .panel)
        if let run { selecting = run }
        if link.isAsking {
            if need == .change { readsAgain = true }
            if reason.isEvent { eventAgain = reason }
            return
        }
        if need == .moment, let answered, runs.now().timeIntervalSince(answered) < Self.answerAge {
            selectKept()
            return
        }
        let query = list.search == .script && !link.keepsState ? list.query : ""
        let read = SpotAction.read
        let action = spot.read == nil ? spot.click : read
        let values = [showsSheet ? panel?.values : nil, query.isEmpty ? nil : SearchQuery(text: query).input].compactMap { $0 }
        let isSent = link.send(Call(
            action: action,
            key: Self.readKey,
            input: values.isEmpty ? nil : values.joined(),
            limit: action == read ? runs.readLimit : nil,
            reason: reason,
            variables: action == read ? reason.variables : [:],
            purpose: .ask(.read(generation: panel?.generation, reports: need != .clock, query: query, tells: reason != .panel))
        ))
        if isSent, !list.holdsItems || list.hasFailed { list.beginLoading() }
    }

    /// Takes new text in the search. A newer search stops the older one, and the script hears after a pause.
    public func search(_ text: String) {
        guard list.search(text), list.search == .script else { return }
        if let older = running(Self.searchKey) { stop(older) }
        after(Self.textPause, key: Self.searchKey) { [weak self] in self?.ask() }
    }

    /// Asks the script about the current search, with the values of the sheet and the text on stdin. A newer search stops
    /// the older one. This never waits: `search` holds the pause.
    func ask() {
        let query = list.query
        if let older = running(Self.searchKey) { stop(older) }
        pauses[Self.searchKey]?.cancel()
        pauses[Self.searchKey] = nil
        link.send(Call(
            action: .read,
            key: Self.searchKey,
            input: (showsSheet ? panel?.values ?? "" : "") + SearchQuery(text: query).input,
            limit: runs.readLimit,
            reason: .text(query, inSheet: true),
            variables: ReadReason.text(query, inSheet: true).variables,
            purpose: .ask(.search(query))
        ))
    }

    /// Asks the script for the rows that answer a text of the main search, at once, and stops the older ask. An empty text
    /// drops the answers (protocol: Places).
    public func answer(_ text: String) {
        guard text != answerQuery else { return }
        answerQuery = text
        if let older = running(Self.answerKey) { stop(older) }
        guard !text.isEmpty else {
            answeredQuery = ""
            answerWaiters = []
            takeAnswers([])
            return
        }
        link.send(Call(
            action: .read,
            key: Self.answerKey,
            input: SearchQuery(text: text).input,
            limit: runs.readLimit,
            reason: .text(text, inSheet: false),
            variables: ReadReason.text(text, inSheet: false).variables,
            purpose: .ask(.answer(text))
        ))
    }

    /// Runs the work once the newest text is answered, or at once when it is.
    public func afterAnswers(_ work: @escaping () -> Void) {
        if isAnswering { answerWaiters.append(work) } else { work() }
    }

    /// Takes the rows that answer a text, and runs the work that waited for them when the text is the newest.
    func takeAnswers(_ rows: [SpotItem], to query: String? = nil) {
        if let query {
            guard query == answerQuery else { return }
            answeredQuery = query
        }
        if rows != answers {
            answers = rows
            onReport(.listChange)
        }
        guard !isAnswering else { return }
        let waiting = answerWaiters
        answerWaiters = []
        waiting.forEach { $0() }
    }

    /// Whether a read or a search of this script waits for its answer.
    var isReading: Bool {
        link.isAsking
    }

    private func selectKept() {
        guard let run = selecting else { return }
        selecting = nil
        list.select(run: run)
    }

    func answerArrived() {
        hasAsked = true
        let work = waiter
        waiter = nil
        work?()
        runs.opening.startMotion(of: spot.id)
    }

    /// Reads again when a change or an event came during a read, once no read or search waits. The newest event gives
    /// the reason.
    func readAgainIfAsked() {
        guard readsAgain || eventAgain != nil, !link.isAsking else { return }
        let need: ReadNeed = readsAgain ? .change : .clock
        let reason = eventAgain
        readsAgain = false
        eventAgain = nil
        read(need: need, reason: reason)
    }

    func readOnce() {
        if spot.read != nil { read(need: .change) }
    }
}
