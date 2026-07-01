import XCTest
import SwiftData
@testable import Luo

@MainActor
final class CastRecordTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CastRecord.self, configurations: config)
        return ModelContext(container)
    }

    private func qianAllChanging() -> Hexagram {
        Hexagram(yao: Array(repeating: Yao(faces: [.heads, .heads, .heads]), count: 6))
    }

    func testInsertFetchReconstructs() throws {
        let ctx = try makeContext()
        ctx.insert(CastRecord(from: qianAllChanging(), at: Date(timeIntervalSince1970: 0)))
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<CastRecord>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.hexagram.number, 1)                     // 乾
        XCTAssertEqual(all.first?.hexagram.changingPositions.count, 6)
    }

    func testDeleteAndDeleteAll() throws {
        let ctx = try makeContext()
        for _ in 0..<3 { ctx.insert(CastRecord(from: qianAllChanging(), at: Date(timeIntervalSince1970: 0))) }
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<CastRecord>())
        ctx.delete(all[0]); try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<CastRecord>()).count, 2)
        try ctx.fetch(FetchDescriptor<CastRecord>()).forEach(ctx.delete); try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<CastRecord>()).count, 0)
    }
}
