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
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    
    private init(databaseName: String = "trafficmaster.v2.db") {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.dbPath = documentsPath.appendingPathComponent(databaseName).path
        
        openDatabase()
        createTables()
    }
    
    deinit {
        closeDatabase()
    }
    
    private func getErrorMessage() -> String {
        if let err = sqlite3_errmsg(db) {
            return String(cString: err)
        }
        return "Unknown SQLite error"
    }
    
    private func openDatabase() {
        let rc = sqlite3_open(dbPath, &db)
        if rc != SQLITE_OK {
            print("Cannot open database: \(getErrorMessage())")
            sqlite3_close(db)
            db = nil
        } else {
            print("Database opened successfully at: \(dbPath)")
        }
    }
    
    private func closeDatabase() {
        sqlite3_close(db)
    }
    
    private func createTables() {
        var errMsg: UnsafeMutablePointer<CChar>?
        
        if sqlite3_exec(db, DatabaseSchema.createQuestionsTable, nil, nil, &errMsg) != SQLITE_OK {
            let errStr = errMsg.map { String(cString: $0) } ?? "Unknown error"
            print("Error creating questions table: \(errStr)")
            sqlite3_free(errMsg)
        }
        
        if sqlite3_exec(db, DatabaseSchema.createRevlogsTable, nil, nil, &errMsg) != SQLITE_OK {
            let errStr = errMsg.map { String(cString: $0) } ?? "Unknown error"
            print("Error creating revlogs table: \(errStr)")
            sqlite3_free(errMsg)
        }
        
        if sqlite3_exec(db, DatabaseSchema.createIndexes, nil, nil, &errMsg) != SQLITE_OK {
            let errStr = errMsg.map { String(cString: $0) } ?? "Unknown error"
            print("Error creating indexes: \(errStr)")
            sqlite3_free(errMsg)
        }
    }
    
    // MARK: - Question Operations
    
    func saveQuestion(_ q: Question) throws {
        let query = """
        INSERT OR REPLACE INTO questions 
        (id, text, options, correct_answer_index, explanation, image_name, section_title, chapter_title, stability, difficulty, retrievability, repetitions, interval, easiness_factor, next_review_date) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(getErrorMessage())
        }
        
        sqlite3_bind_text(statement, 1, q.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, q.text, -1, SQLITE_TRANSIENT)
        
        if let optionsData = try? JSONEncoder().encode(q.options), let optionsStr = String(data: optionsData, encoding: .utf8) {
            sqlite3_bind_text(statement, 3, optionsStr, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_text(statement, 3, "[]", -1, SQLITE_TRANSIENT)
        }
        
        sqlite3_bind_int(statement, 4, Int32(q.correctAnswerIndex))
        
        if let explanation = q.explanation {
            sqlite3_bind_text(statement, 5, explanation, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 5)
        }
        
        if let imageName = q.imageName {
            sqlite3_bind_text(statement, 6, imageName, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 6)
        }
        
        if let st = q.sectionTitle {
            sqlite3_bind_text(statement, 7, st, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 7)
        }
        
        if let ct = q.chapterTitle {
            sqlite3_bind_text(statement, 8, ct, -1, SQLITE_TRANSIENT)
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
            if let q = try? parseQuestion(statement: statement!) {
                results.append(q)
            }
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
            if let q = try? parseQuestion(statement: statement!) {
                results.append(q)
            }
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
        
        sqlite3_bind_text(statement, 1, revlog.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, revlog.cardId.uuidString, -1, SQLITE_TRANSIENT)
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
    
    private func parseQuestion(statement: OpaquePointer) throws -> Question {
        // Безопасное чтение ID
        guard let idCStr = sqlite3_column_text(statement, 0),
              let id = UUID(uuidString: String(cString: idCStr)) else {
            throw DatabaseError.executeFailed("Invalid or missing ID")
        }
        
        // Безопасное чтение Текста
        let text = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
        
        // Безопасное чтение Вариантов ответов
        let optionsStr = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? "[]"
        let options = (try? JSONDecoder().decode([String].self, from: Data(optionsStr.utf8))) ?? []
        
        let correctIndex = Int(sqlite3_column_int(statement, 3))
        
        let explanation = sqlite3_column_text(statement, 4).map { String(cString: $0) }
        let imageName = sqlite3_column_text(statement, 5).map { String(cString: $0) }
        let sectionTitle = sqlite3_column_text(statement, 6).map { String(cString: $0) }
        let chapterTitle = sqlite3_column_text(statement, 7).map { String(cString: $0) }
        
        let stability = sqlite3_column_double(statement, 8)
        let difficulty = sqlite3_column_double(statement, 9)
        let retrievability = sqlite3_column_double(statement, 10)
        let repetitions = Int(sqlite3_column_int(statement, 11))
        let interval = Int(sqlite3_column_int(statement, 12))
        let easinessFactor = sqlite3_column_double(statement, 13)
        let nextReviewDate = Date(timeIntervalSince1970: sqlite3_column_double(statement, 14))
        
        return Question(
            id: id,
            text: text,
            options: options,
            correctAnswerIndex: correctIndex,
            explanation: explanation,
            imageName: imageName,
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
