// Debug-only diagnostics for the tab-bar badge: the device's bar hierarchy diverges from the simulator's (the
// owner's blink and expand plateau reproduce only there), so every pane event records a 2 s tail of the bar's
// real shape — and of the window above it, where the device may mount its selection glass — into a ring-buffered
// file in Documents, pullable with devicectl. Ids and class names only, never content; buffered background
// writes keep it off the render path. Compiled out of Release and Staging builds.
#if DEBUG
import UIKit

@MainActor
final class BadgePaneDiagnostics {
    static let shared = BadgePaneDiagnostics()
    private static let fileName = "badge-pane-diagnostics.log"
    private static let ringCapacity = 4000
    private static let tailSeconds: CFTimeInterval = 2.0
    // Nonisolated: referenced from the init's default argument, which evaluates outside the actor.
    nonisolated private static let flushDelaySeconds: TimeInterval = 0.5
    /// Enough frames to see a morph, far under the viewer's full-rate clock.
    private static let frameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 20)
    private static let classNameLength = 18
    /// Each window walk logs at most this many entries per list; the bar's region holds only a few views.
    private static let maxWindowEntries = 20

    private(set) var lines: [String] = []
    private(set) var isSampling = false
    private let clock: FrameClock
    private let now: () -> CFTimeInterval
    private let flushDelay: TimeInterval
    private let writeSink: @Sendable (String, URL) -> Void
    private var stopAt: CFTimeInterval = 0
    private struct WeakView {
        weak var view: UIView?
    }

    private weak var bar: UITabBar?
    private var capsules: [WeakView] = []
    private var flushPending = false
    private let writer = DispatchQueue(label: "badge-pane-diagnostics", qos: .utility)
    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(fileName)

    /// A nil clock takes the production display link (a default argument would build it nonisolated).
    init(clock: FrameClock? = nil,
         now: @escaping () -> CFTimeInterval = CACurrentMediaTime,
         flushDelay: TimeInterval = BadgePaneDiagnostics.flushDelaySeconds,
         writeSink: @escaping @Sendable (String, URL) -> Void = { text, target in
             try? text.write(to: target, atomically: true, encoding: .utf8)
         }) {
        self.clock = clock ?? DisplayLinkFrameClock(frameRate: Self.frameRateRange)
        self.now = now
        self.flushDelay = flushDelay
        self.writeSink = writeSink
    }

    /// Records one event and keeps sampling the bar for a short tail; a repeated event extends the tail.
    /// The live capsules the tail samples; re-registered on every hosts change (a resolve, a retire, the
    /// teardown), so a tail around a hand-off still sees them.
    func register(capsules: [UIView]) {
        self.capsules = capsules.map { WeakView(view: $0) }
    }

    func note(_ event: String, bar: UITabBar?, capsules: [UIView]) {
        self.bar = bar
        register(capsules: capsules)
        append("event \(event)")
        stopAt = now() + Self.tailSeconds
        guard !isSampling else { return }
        isSampling = true
        clock.start { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard now() <= stopAt else {
            clock.stop()
            isSampling = false
            return
        }
        guard let bar else { return }
        var line = "panes"
        for pane in bar.subviews {
            line += Self.entry(for: pane, in: bar)
        }
        for (index, box) in capsules.enumerated() {
            line += describe(box.view, as: "cap\(index)")
        }
        line += windowLine(for: bar)
        append(line)
    }

    /// Where the device mounts its glass is unanswerable from the bar's subviews alone: one level of the window,
    /// plus any deeper view outside the bar's own subtree whose frame overlaps the bar.
    private func windowLine(for bar: UITabBar) -> String {
        guard let window = bar.window else { return " window=nil" }
        var line = " window:"
        for view in window.subviews.prefix(Self.maxWindowEntries) {
            line += Self.entry(for: view, in: window)
        }
        let barFrame = bar.convert(bar.bounds, to: window)
        line += " overBar:"
        var logged = 0
        var queue: [UIView] = window.subviews
        var index = 0
        while index < queue.count, logged < Self.maxWindowEntries {
            let view = queue[index]
            index += 1
            if view === bar { continue }
            queue.append(contentsOf: view.subviews)
            let frame = view.convert(view.bounds, to: window)
            if !view.isHidden, frame.intersects(barFrame) {
                line += Self.entry(for: view, in: window)
                logged += 1
            }
        }
        return line
    }

    private static func entry(for view: UIView, in reference: UIView) -> String {
        let name = String(String(describing: type(of: view)).suffix(classNameLength))
        let frame = view.convert(view.bounds, to: reference)
        let box = String(format: "%.0fx%.0f@%.0f,%.0f", frame.width, frame.height, frame.minX, frame.minY)
        let alpha = String(format: "a=%.2f po=%.2f", view.alpha, view.layer.presentation()?.opacity ?? -1)
        return " [\(name) \(box) h=\(view.isHidden ? 1 : 0) \(alpha)]"
    }

    private func describe(_ view: UIView?, as role: String) -> String {
        guard let view else { return "" }
        let opacity = String(format: "%.2f", view.layer.presentation()?.opacity ?? -1)
        return " \(role)[h=\(view.isHidden ? 1 : 0) win=\(view.window != nil ? 1 : 0) po=\(opacity)]"
    }

    /// The ring keeps the newest lines; a session that morphs for an hour still pulls a bounded file.
    private func append(_ line: String) {
        lines.append(String(format: "t=%.3f ", now()) + line)
        if lines.count > Self.ringCapacity { lines.removeFirst(lines.count - Self.ringCapacity) }
        scheduleFlush()
    }

    /// At most one pending write; the lines are snapshot on the main actor, joined and written off it.
    private func scheduleFlush() {
        guard !flushPending else { return }
        flushPending = true
        writer.asyncAfter(deadline: .now() + flushDelay) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.flushPending = false
                let snapshot = self.lines
                let sink = self.writeSink
                let target = self.url
                self.writer.async { sink(snapshot.joined(separator: "\n") + "\n", target) }
            }
        }
    }
}
#endif
