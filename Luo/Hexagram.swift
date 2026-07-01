import Foundation

/// The Present Hexagram (本卦) read directly from 6 Throws. Yao are stored
/// bottom→top (index 0 = bottom = first Throw). ① renders 本卦 only; 变卦 and
/// canonical text are Sub-project ②.
struct Hexagram: Equatable {
    let yao: [Yao]

    /// Requires exactly 6 Yao.
    init(yao: [Yao]) {
        precondition(yao.count == 6, "A Hexagram needs exactly 6 Yao")
        self.yao = yao
    }

    /// 6-bit key, bottom→top, yang = 1 (bit 0 = bottom Yao).
    var presentBits: Int {
        var v = 0
        for (i, y) in yao.enumerated() where y.isYang { v |= (1 << i) }
        return v
    }

    /// 1-based positions (1 = bottom) of the Changing Yao.
    var changingPositions: [Int] {
        yao.enumerated().filter { $0.element.isChanging }.map { $0.offset + 1 }
    }

    /// The Resulting Hexagram (变卦): each changing Yao flips to the opposite
    /// static line; each non-changing Yao becomes a static line of the same
    /// polarity. `nil` when there are no changing Yao. The 变卦 is itself static
    /// (none of its lines are changing).
    var resultingHexagram: Hexagram? {
        guard !changingPositions.isEmpty else { return nil }
        let lines = yao.map { Yao(isYang: $0.isChanging ? !$0.isYang : $0.isYang) }
        return Hexagram(yao: lines)
    }

    private var info: HexagramInfo { KingWenTable.info(forBits: presentBits) }
    var number: Int { info.number }
    var name: String { info.name }
}
