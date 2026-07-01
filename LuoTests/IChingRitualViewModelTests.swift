import XCTest
@testable import Luo

@MainActor
final class IChingRitualViewModelTests: XCTestCase {
    private let youngYang = [CoinFace.heads, .tails, .tails]  // 1 head -> yang
    private let youngYin  = [CoinFace.heads, .heads, .tails]  // 2 heads -> yin

    func testSixYoungYangThrowsCompleteAsQian() {
        let vm = IChingRitualViewModel()
        for _ in 0..<6 { vm.appendThrow(youngYang) }
        guard case .complete(let hex) = vm.state else {
            return XCTFail("expected .complete, got \(vm.state)")
        }
        XCTAssertEqual(hex.number, 1)
        XCTAssertEqual(hex.name, "乾")
        XCTAssertEqual(vm.castYao.count, 6)
    }

    func testStaysIdleBetweenThrows() {
        let vm = IChingRitualViewModel()
        vm.appendThrow(youngYang)
        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(vm.castYao.count, 1)
    }

    func testResetClearsAccumulation() {
        let vm = IChingRitualViewModel()
        for _ in 0..<3 { vm.appendThrow(youngYin) }
        vm.reset()
        XCTAssertEqual(vm.state, .idle)
        XCTAssertTrue(vm.castYao.isEmpty)
    }

    func testSeventhThrowIsIgnored() {
        let vm = IChingRitualViewModel()
        for _ in 0..<6 { vm.appendThrow(youngYang) }
        vm.appendThrow(youngYin) // ignored once complete
        XCTAssertEqual(vm.castYao.count, 6)
    }
}
