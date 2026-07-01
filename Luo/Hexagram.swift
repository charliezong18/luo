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

    private var info: HexagramInfo { KingWenTable.info(forBits: presentBits) }
    var number: Int { info.number }
    var name: String { info.name }
}
