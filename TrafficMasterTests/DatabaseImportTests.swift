import Foundation
import Testing
@testable import TrafficMaster

struct DatabaseImportTests {
    @Test("Question import maps correct option")
    func importAndMapping() throws {
        let db = DatabaseService.shared
        let dto = QuestionImportDTO(
            hierarchy: "ПДД ➔ Глава 1 ➔ Тест",
            question: "Тестовый вопрос для импорта",
            image: nil,
            options: ["1) Неверный", "2) Верный"],
            correctIndex: 1,
            correctText: "Верный",
            explanation: "Потому что так написано в правиле."
        )

        try db.upsertQuestions([dto])

        let cards = try db.fetchSessionCards(newLimit: 5000, maxReviews: 5000)
        let card = cards.first(where: { $0.question.text == "Тестовый вопрос для импорта" })

        #expect(card != nil)
        #expect(card?.question.options.count == 2)
        #expect(card?.question.options.first(where: { $0.id == card?.question.correctOptionID })?.isCorrect == true)
    }

    @Test("Broken records are ignored")
    func invalidQuestionIgnored() throws {
        let db = DatabaseService.shared
        let before = try db.fetchSessionCards(newLimit: 5000, maxReviews: 5000).count

        let broken = QuestionImportDTO(
            hierarchy: "ПДД",
            question: "   ",
            image: nil,
            options: ["1) A"],
            correctIndex: 0,
            correctText: "A",
            explanation: nil
        )

        try db.upsertQuestions([broken])
        let after = try db.fetchSessionCards(newLimit: 5000, maxReviews: 5000).count

        #expect(after == before)
    }
}
