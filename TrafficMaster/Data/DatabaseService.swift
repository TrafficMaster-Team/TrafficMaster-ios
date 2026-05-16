//
//  DatabaseService.swift
//  TrafficMaster
//
//  Data Layer - SQLite Database Service
//

import Foundation
import SQLite3

/// Сервис для работы с SQLite базой данных
class DatabaseService {

    static let shared = DatabaseService()

    private var db: OpaquePointer?
    private let dbPath: String
    private static let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    // MARK: - Column Index Constants (must match CREATE TABLE column order)
    private enum QuestionColumn: Int {
        case id = 0
        case text
        case options
        case correctAnswerIndex
        case explanation
        case imageName
        case sectionTitle
        case chapterTitle
        case stability
        case difficulty
        case retrievability
        case repetitions
        case interval
        case easinessFactor
        case nextReviewDate
        case answerOptionsJSON
        case backendCardID
        case backendDeckID
    }

    private init(databaseName: String = "trafficmaster.v2.db") {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.dbPath = documentsPath.appendingPathComponent(databaseName).path

        do {
            try openDatabase()
            try createTables()
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }

    deinit {
        closeDatabase()
    }

    private func getErrorMessage() -> String {
        guard let db = db else { return "Database not open" }
        if let err = sqlite3_errmsg(db) {
            return String(cString: err)
        }
        return "Unknown SQLite error"
    }

    private func openDatabase() throws {
        let rc = sqlite3_open(dbPath, &db)
        if rc != SQLITE_OK {
            let error = getErrorMessage()
            print("Cannot open database: \(error)")
            sqlite3_close(db)
            db = nil
            throw DatabaseError.executeFailed(error)
        } else {
            print("Database opened successfully at: \(dbPath)")
        }
    }

    private func closeDatabase() {
        guard let db = db else { return }
        sqlite3_close(db)
    }

    private func createTables() throws {
        var errMsg: UnsafeMutablePointer<CChar>?

        if sqlite3_exec(db, DatabaseSchema.createQuestionsTable, nil, nil, &errMsg) != SQLITE_OK {
            let errStr = errMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errMsg)
            throw DatabaseError.executeFailed("CREATE questions table: \(errStr)")
        }

        if sqlite3_exec(db, DatabaseSchema.createRevlogsTable, nil, nil, &errMsg) != SQLITE_OK {
            let errStr = errMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errMsg)
            throw DatabaseError.executeFailed("CREATE revlogs table: \(errStr)")
        }
        
        if sqlite3_exec(db, DatabaseSchema.createSyncOutboxTable, nil, nil, &errMsg) != SQLITE_OK {
            let errStr = errMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errMsg)
            throw DatabaseError.executeFailed("CREATE sync_outbox table: \(errStr)")
        }
        
        try migrateQuestionsTableIfNeeded()

        if sqlite3_exec(db, DatabaseSchema.createIndexes, nil, nil, &errMsg) != SQLITE_OK {
            let errStr = errMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errMsg)
            throw DatabaseError.executeFailed("CREATE indexes: \(errStr)")
        }
    }
    
    // MARK: - Question Operations
    
    func saveQuestion(_ q: Question) throws {
        let query = """
        INSERT OR REPLACE INTO questions 
        (id, text, options, correct_answer_index, explanation, image_name, section_title, chapter_title, stability, difficulty, retrievability, repetitions, interval, easiness_factor, next_review_date, answer_options_json, backend_card_id, backend_deck_id) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(getErrorMessage())
        }
        
        sqlite3_bind_text(statement, 1, q.id.uuidString, -1, Self.SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, q.text, -1, Self.SQLITE_TRANSIENT)

        let optionsData = try JSONEncoder().encode(q.options)
        guard let optionsStr = String(data: optionsData, encoding: .utf8) else {
            throw DatabaseError.executeFailed("Failed to encode options as UTF-8")
        }
        sqlite3_bind_text(statement, 3, optionsStr, -1, Self.SQLITE_TRANSIENT)
        
        sqlite3_bind_int(statement, 4, Int32(q.correctAnswerIndex))
        
        if let explanation = q.explanation {
            sqlite3_bind_text(statement, 5, explanation, -1, Self.SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 5)
        }

        if let imageName = q.imageName {
            sqlite3_bind_text(statement, 6, imageName, -1, Self.SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 6)
        }

        if let st = q.sectionTitle {
            sqlite3_bind_text(statement, 7, st, -1, Self.SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 7)
        }

        if let ct = q.chapterTitle {
            sqlite3_bind_text(statement, 8, ct, -1, Self.SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 8)
        }
        
        sqlite3_bind_double(statement, 9, q.stability)
        sqlite3_bind_double(statement, 10, q.difficulty)
        sqlite3_bind_double(statement, 11, q.retrievability)
        sqlite3_bind_int(statement, 12, Int32(q.repetitions))
        sqlite3_bind_int(statement, 13, Int32(q.interval))
        sqlite3_bind_double(statement, 14, q.easinessFactor)
        sqlite3_bind_double(statement, 15, q.nextReviewDate.timeIntervalSince1970)
        
        if !q.answerOptions.isEmpty {
            let answerOptionsData = try JSONEncoder().encode(q.answerOptions)
            guard let answerOptionsJSON = String(data: answerOptionsData, encoding: .utf8) else {
                throw DatabaseError.executeFailed("Failed to encode answer options as UTF-8")
            }
            sqlite3_bind_text(statement, 16, answerOptionsJSON, -1, Self.SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 16)
        }
        
        if let backendCardID = q.backendCardID {
            sqlite3_bind_text(statement, 17, backendCardID.uuidString, -1, Self.SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 17)
        }
        
        if let backendDeckID = q.backendDeckID {
            sqlite3_bind_text(statement, 18, backendDeckID.uuidString, -1, Self.SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 18)
        }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorStr = getErrorMessage()
            sqlite3_finalize(statement)
            throw DatabaseError.executeFailed(errorStr)
        }
        
        sqlite3_finalize(statement)
    }
    
    func fetchAllQuestions() throws -> [Question] {
        let query = "SELECT * FROM questions"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(getErrorMessage())
        }
        
        var results: [Question] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(try parseQuestion(statement: statement))
        }

        sqlite3_finalize(statement)
        return results
    }

    func fetchDueQuestions(limit: Int = 100) throws -> [Question] {
        let now = Date().timeIntervalSince1970
        let query = "SELECT * FROM questions WHERE next_review_date <= ? LIMIT ?"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(getErrorMessage())
        }

        sqlite3_bind_double(statement, 1, now)
        sqlite3_bind_int(statement, 2, Int32(limit))

        var results: [Question] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(try parseQuestion(statement: statement))
        }
        
        sqlite3_finalize(statement)
        return results
    }

    func countQuestions() throws -> Int {
        return try countTable("questions")
    }
    
    // MARK: - Revlog Operations
    
    func saveRevlog(_ revlog: Revlog) throws {
        let query = "INSERT INTO revlogs (id, card_id, review_datetime, grade, time_taken, pre_stability, pre_difficulty) VALUES (?, ?, ?, ?, ?, ?, ?)"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(getErrorMessage())
        }
        
        sqlite3_bind_text(statement, 1, revlog.id.uuidString, -1, Self.SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, revlog.cardId.uuidString, -1, Self.SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 3, revlog.reviewDatetime.timeIntervalSince1970)
        sqlite3_bind_int(statement, 4, Int32(revlog.grade))
        sqlite3_bind_int(statement, 5, Int32(revlog.timeTaken))
        sqlite3_bind_double(statement, 6, revlog.preStability)
        sqlite3_bind_double(statement, 7, revlog.preDifficulty)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorStr = getErrorMessage()
            sqlite3_finalize(statement)
            throw DatabaseError.executeFailed(errorStr)
        }
        
        sqlite3_finalize(statement)
    }
    
    // MARK: - Sync Outbox Operations
    
    func enqueueReviewEvent(_ event: SyncReviewEvent) throws {
        let query = """
        INSERT OR REPLACE INTO sync_outbox
        (id, card_id, selected_option_id, rating, answered_at, time_spent_ms, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(getErrorMessage())
        }
        
        sqlite3_bind_text(statement, 1, event.id.uuidString, -1, Self.SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, event.cardId.uuidString, -1, Self.SQLITE_TRANSIENT)
        
        if let selectedOptionID = event.selectedOptionID {
            sqlite3_bind_text(statement, 3, selectedOptionID.uuidString, -1, Self.SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 3)
        }
        
        sqlite3_bind_int(statement, 4, Int32(event.rating.rawValue))
        sqlite3_bind_double(statement, 5, event.answeredAt.timeIntervalSince1970)
        sqlite3_bind_int(statement, 6, Int32(event.timeSpentMs))
        sqlite3_bind_double(statement, 7, event.createdAt.timeIntervalSince1970)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorStr = getErrorMessage()
            sqlite3_finalize(statement)
            throw DatabaseError.executeFailed(errorStr)
        }
        
        sqlite3_finalize(statement)
    }
    
    func fetchPendingReviewEvents(limit: Int = 100) throws -> [SyncReviewEvent] {
        let query = """
        SELECT id, card_id, selected_option_id, rating, answered_at, time_spent_ms, created_at
        FROM sync_outbox
        WHERE synced_at IS NULL
        ORDER BY created_at ASC
        LIMIT ?
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(getErrorMessage())
        }
        
        sqlite3_bind_int(statement, 1, Int32(limit))
        
        var events: [SyncReviewEvent] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idText = sqlite3_column_text(statement, 0),
                  let id = UUID(uuidString: String(cString: idText)),
                  let cardIdText = sqlite3_column_text(statement, 1),
                  let cardID = UUID(uuidString: String(cString: cardIdText))
            else {
                continue
            }
            
            let selectedOptionID = sqlite3_column_text(statement, 2).flatMap { UUID(uuidString: String(cString: $0)) }
            let ratingRaw = Int(sqlite3_column_int(statement, 3))
            let rating = ReviewRating(rawValue: ratingRaw) ?? .again
            let answeredAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))
            let timeSpentMs = Int(sqlite3_column_int(statement, 5))
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 6))
            
            events.append(
                SyncReviewEvent(
                    id: id,
                    cardId: cardID,
                    selectedOptionID: selectedOptionID,
                    rating: rating,
                    answeredAt: answeredAt,
                    timeSpentMs: timeSpentMs,
                    createdAt: createdAt
                )
            )
        }
        
        sqlite3_finalize(statement)
        return events
    }
    
    func markReviewEventsSynced(eventIDs: [UUID]) throws {
        guard !eventIDs.isEmpty else { return }
        
        let placeholders = Array(repeating: "?", count: eventIDs.count).joined(separator: ",")
        let query = "UPDATE sync_outbox SET synced_at = ? WHERE id IN (\(placeholders))"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(getErrorMessage())
        }
        
        sqlite3_bind_double(statement, 1, Date().timeIntervalSince1970)
        for (index, id) in eventIDs.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 2), id.uuidString, -1, Self.SQLITE_TRANSIENT)
        }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorStr = getErrorMessage()
            sqlite3_finalize(statement)
            throw DatabaseError.executeFailed(errorStr)
        }
        
        sqlite3_finalize(statement)
    }
    
    // MARK: - Transaction Support
    
    func executeTransaction(_ block: () throws -> Void) throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        
        guard sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, &errMsg) == SQLITE_OK else {
            let errorStr = errMsg.map { String(cString: $0) } ?? getErrorMessage()
            sqlite3_free(errMsg)
            throw DatabaseError.transactionFailed("BEGIN: \(errorStr)")
        }
        
        do {
            try block()
            
            guard sqlite3_exec(db, "COMMIT", nil, nil, &errMsg) == SQLITE_OK else {
                let errorStr = errMsg.map { String(cString: $0) } ?? getErrorMessage()
                sqlite3_free(errMsg)
                throw DatabaseError.transactionFailed("COMMIT: \(errorStr)")
            }
        } catch {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            throw error
        }
    }
    
    // MARK: - Private Helpers
    
    private func countTable(_ tableName: String) throws -> Int {
        let query = "SELECT COUNT(*) FROM \(tableName)"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(getErrorMessage())
        }
        
        var count: Int = 0
        if sqlite3_step(statement) == SQLITE_ROW {
            count = Int(sqlite3_column_int(statement, 0))
        }
        
        sqlite3_finalize(statement)
        return count
    }
    
    private func parseQuestion(statement: OpaquePointer?) throws -> Question {
        guard let statement = statement else {
            throw DatabaseError.executeFailed("Statement is nil")
        }

        // Безопасное чтение ID
        guard let idCStr = sqlite3_column_text(statement, Int32(QuestionColumn.id.rawValue)),
              let id = UUID(uuidString: String(cString: idCStr)) else {
            throw DatabaseError.executeFailed("Invalid or missing ID")
        }

        // Безопасное чтение Текста
        let text = sqlite3_column_text(statement, Int32(QuestionColumn.text.rawValue)).map { String(cString: $0) } ?? ""

        // Безопасное чтение Вариантов ответов
        let optionsStr = sqlite3_column_text(statement, Int32(QuestionColumn.options.rawValue)).map { String(cString: $0) } ?? "[]"
        let options = try JSONDecoder().decode([String].self, from: Data(optionsStr.utf8))

        let correctIndex = Int(sqlite3_column_int(statement, Int32(QuestionColumn.correctAnswerIndex.rawValue)))

        let explanation = sqlite3_column_text(statement, Int32(QuestionColumn.explanation.rawValue)).map { String(cString: $0) }
        let imageName = sqlite3_column_text(statement, Int32(QuestionColumn.imageName.rawValue)).map { String(cString: $0) }
        let sectionTitle = sqlite3_column_text(statement, Int32(QuestionColumn.sectionTitle.rawValue)).map { String(cString: $0) }
        let chapterTitle = sqlite3_column_text(statement, Int32(QuestionColumn.chapterTitle.rawValue)).map { String(cString: $0) }

        let stability = sqlite3_column_double(statement, Int32(QuestionColumn.stability.rawValue))
        let difficulty = sqlite3_column_double(statement, Int32(QuestionColumn.difficulty.rawValue))
        let retrievability = sqlite3_column_double(statement, Int32(QuestionColumn.retrievability.rawValue))
        let repetitions = Int(sqlite3_column_int(statement, Int32(QuestionColumn.repetitions.rawValue)))
        let interval = Int(sqlite3_column_int(statement, Int32(QuestionColumn.interval.rawValue)))
        let easinessFactor = sqlite3_column_double(statement, Int32(QuestionColumn.easinessFactor.rawValue))
        let nextReviewDate = Date(timeIntervalSince1970: sqlite3_column_double(statement, Int32(QuestionColumn.nextReviewDate.rawValue)))
        
        let answerOptionsJSON = sqlite3_column_text(statement, Int32(QuestionColumn.answerOptionsJSON.rawValue)).map { String(cString: $0) }
        let answerOptions: [AnswerOption]
        if let answerOptionsJSON {
            answerOptions = (try? JSONDecoder().decode([AnswerOption].self, from: Data(answerOptionsJSON.utf8))) ?? []
        } else {
            answerOptions = []
        }
        
        let backendCardID = sqlite3_column_text(statement, Int32(QuestionColumn.backendCardID.rawValue))
            .flatMap { UUID(uuidString: String(cString: $0)) }
        let backendDeckID = sqlite3_column_text(statement, Int32(QuestionColumn.backendDeckID.rawValue))
            .flatMap { UUID(uuidString: String(cString: $0)) }

        let question = Question(
            id: id,
            text: text,
            options: options,
            answerOptions: answerOptions,
            correctAnswerIndex: correctIndex,
            explanation: explanation,
            imageName: imageName,
            backendCardID: backendCardID,
            backendDeckID: backendDeckID,
            sectionTitle: sectionTitle,
            chapterTitle: chapterTitle,
            stability: stability,
            difficulty: difficulty,
            retrievability: retrievability,
            repetitions: repetitions,
            interval: interval,
            easinessFactor: easinessFactor,
            nextReviewDate: nextReviewDate
        )
        // Валидация FSRS/SM-2 значений после загрузки из БД
        question.validateAndFixDefaults()
        return question
    }
    
    private func migrateQuestionsTableIfNeeded() throws {
        try ensureQuestionColumnExists("answer_options_json", type: "TEXT")
        try ensureQuestionColumnExists("backend_card_id", type: "TEXT")
        try ensureQuestionColumnExists("backend_deck_id", type: "TEXT")
    }
    
    private func ensureQuestionColumnExists(_ name: String, type: String) throws {
        guard !questionColumnExists(name) else { return }
        let sql = "ALTER TABLE questions ADD COLUMN \(name) \(type)"
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw DatabaseError.executeFailed("ALTER TABLE questions ADD COLUMN \(name): \(getErrorMessage())")
        }
    }
    
    private func questionColumnExists(_ name: String) -> Bool {
        let query = "PRAGMA table_info(questions)"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        var exists = false
        while sqlite3_step(statement) == SQLITE_ROW {
            if let colName = sqlite3_column_text(statement, 1).map({ String(cString: $0) }),
               colName == name {
                exists = true
                break
            }
        }
        
        sqlite3_finalize(statement)
        return exists
    }
}

// MARK: - Statistics

struct DatabaseStatistics {
    let questionsCount: Int
    let revlogsCount: Int
}

// MARK: - Errors

enum DatabaseError: LocalizedError {
    case prepareFailed(String)
    case executeFailed(String)
    case transactionFailed(String)
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .prepareFailed(let msg): return "Prepare failed: \(msg)"
        case .executeFailed(let msg): return "Execute failed: \(msg)"
        case .transactionFailed(let msg): return "Transaction failed: \(msg)"
        case .notFound: return "Not found"
        }
    }
}
