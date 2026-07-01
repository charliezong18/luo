import Foundation
import SwiftData

/// One saved I Ching Cast (ADR-0003 Cast Log). Stores Identifier fields only —
/// `presentBits` + `changingMask` fully determine 卦号/卦名/动爻/变卦; canonical
/// text is looked up from `ZhouYiCorpus` at view time (ADR-0004), so the corpus
/// can grow without rewriting old records.
@Model
final class CastRecord {
    var timestamp: Date
    var presentBits: Int
    var changingMask: Int
    var question: String?
    var note: String?

    init(timestamp: Date, presentBits: Int, changingMask: Int,
         question: String? = nil, note: String? = nil) {
        self.timestamp = timestamp
        self.presentBits = presentBits
        self.changingMask = changingMask
        self.question = question
        self.note = note
    }

    convenience init(from hexagram: Hexagram, at date: Date) {
        var mask = 0
        for pos in hexagram.changingPositions { mask |= (1 << (pos - 1)) }
        self.init(timestamp: date, presentBits: hexagram.presentBits, changingMask: mask)
    }

    /// Reconstruct the full Hexagram for display.
    var hexagram: Hexagram {
        Hexagram(presentBits: presentBits, changingMask: changingMask)
    }
}
