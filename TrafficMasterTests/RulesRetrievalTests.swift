import Foundation
import Testing
@testable import TrafficMaster

struct RulesRetrievalTests {
    @Test("FTS retrieval returns relevant chunks")
    func searchRelevantRule() throws {
        let db = DatabaseService.shared
        try db.upsertRuleChunks([
            LocalRuleChunk(source: "ПДД РБ", title: "Пешеходный переход", text: "Водитель обязан уступить дорогу пешеходу на нерегулируемом переходе."),
            LocalRuleChunk(source: "ПДД РБ", title: "Скорость", text: "В населенных пунктах максимальная скорость ограничена установленными знаками.")
        ], source: "test")

        let hits = try db.searchRules(query: "уступить пешеходу переход", limit: 5)

        #expect(!hits.isEmpty)
        #expect(hits.contains(where: { $0.text.localizedCaseInsensitiveContains("пешеход") }))
    }
}
