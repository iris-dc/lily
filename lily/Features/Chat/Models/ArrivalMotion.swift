import Foundation

/// How the transcript moved while one row arrived, for the log: the frames from the row's arrival until it settled, how
/// far the offset and the content went, and the largest offset step between two frames. Many small steps are a glide;
/// one step near the whole travel is a jump. Reports
/// within `AppConfig.Chat.transcriptFrameWindow` of a frame's first are that frame's layout passes (a lazy stack lays a
/// new row out at an estimated height and corrects it a pass later): only the last of them reaches the screen.
nonisolated struct ArrivalMotion: Equatable, Sendable {
    let rowID: String
    private(set) var frames = 0
    private(set) var offsetTravel: CGFloat = 0
    private(set) var contentGrowth: CGFloat = 0
    private(set) var largestStep: CGFloat = 0
    /// The geometry the last closed frame showed.
    private var shownOffset: CGFloat
    private var shownHeight: CGFloat
    /// A frame still taking reports: when its first came, and its latest geometry.
    private struct OpenFrame: Equatable, Sendable {
        let startedAt: Date
        var offset: CGFloat
        var height: CGFloat
    }

    private var openFrame: OpenFrame?

    init(rowID: String, offset: CGFloat, contentHeight: CGFloat) {
        self.rowID = rowID
        shownOffset = offset
        shownHeight = contentHeight
    }

    mutating func record(offset: CGFloat, contentHeight: CGFloat, at time: Date) {
        if let frame = openFrame, time.timeIntervalSince(frame.startedAt) > AppConfig.Chat.transcriptFrameWindow {
            close(offset: frame.offset, height: frame.height)
            openFrame = nil
        }
        openFrame = OpenFrame(startedAt: openFrame?.startedAt ?? time, offset: offset, height: contentHeight)
    }

    /// The motion in one line, whole points: "offset +57 and content +57 over 41 frames, largest step 3".
    var summary: String {
        var finished = self
        if let frame = finished.openFrame {
            finished.close(offset: frame.offset, height: frame.height)
        }
        return "offset \(signed(finished.offsetTravel)) and content \(signed(finished.contentGrowth)) over "
            + "\(finished.frames) frames, largest step \(Int(finished.largestStep.rounded()))"
    }

    private mutating func close(offset: CGFloat, height: CGFloat) {
        frames += 1
        let step = offset - shownOffset
        offsetTravel += step
        largestStep = max(largestStep, abs(step))
        contentGrowth += height - shownHeight
        shownOffset = offset
        shownHeight = height
    }

    private func signed(_ value: CGFloat) -> String {
        let points = Int(value.rounded())
        return points > 0 ? "+\(points)" : "\(points)"
    }
}
