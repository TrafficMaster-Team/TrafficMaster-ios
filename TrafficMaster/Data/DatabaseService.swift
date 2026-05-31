import Foundation
import SQLite3
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

final class DatabaseService {
    static let shared = DatabaseService()

    private var db: OpaquePointer?
    private let dbPath: String
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private init(databaseName: String = "solouse.fsrs.db") {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        dbPath = documents.appendingPathComponent(databaseName).path
        do {
            try openDatabase()
            try setupSchema()
        } catch {
            fatalError("Database bootstrap failed: \(error)")
        }
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    // MARK: - Public API

    func importBundledQuestionsIfNeeded() throws {
        let sourceSignature = currentSourceSignature()
        let existingSignature = try? readSettingValue(for: "dataset_source_signature")
        let existingCount = try count(query: "SELECT COUNT(*) FROM questions")

        if existingCount > 0, existingSignature == sourceSignature {
            return
        }

        if existingCount > 0, existingSignature != sourceSignature {
            try resetSchema()
            try seedDefaultSettingsIfMissing()
        }

        if let exportURL = DataPackManager.resolvedURL() {
            try importFromExportDirectory(exportURL)
        } else if let asset = NSDataAsset(name: "adrive_questions") {
            let payload = try JSONDecoder().decode([QuestionImportDTO].self, from: asset.data)
            try upsertQuestions(payload)
        } else {
            return
        }

        try seedRulesChunksFromQuestions(limit: 6000)
        try seedRulesChunksFromBundleIfAvailable()
        try upsertSetting(key: "dataset_source_signature", value: sourceSignature)
    }

    func fetchSessionCards(newLimit: Int, maxReviews: Int, now: Date = Date()) throws -> [QuestionCard] {
        let dueIDs = try fetchQuestionIDs(
            query: """
            SELECT q.id
            FROM questions q
            JOIN fsrs_state s ON s.question_id = q.id
            WHERE s.repetitions > 0 AND s.due_at <= ?
            ORDER BY s.due_at ASC
            LIMIT ?
            """,
            bind: { stmt in
                sqlite3_bind_double(stmt, 1, now.timeIntervalSince1970)
                sqlite3_bind_int(stmt, 2, Int32(maxReviews))
            }
        )

        let newIDs = try fetchQuestionIDs(
            query: """
            SELECT q.id
            FROM questions q
            JOIN fsrs_state s ON s.question_id = q.id
            WHERE s.repetitions = 0
            ORDER BY q.created_at ASC
            LIMIT ?
            """,
            bind: { stmt in
                sqlite3_bind_int(stmt, 1, Int32(newLimit))
            }
        )

        return try (dueIDs + newIDs).compactMap { try fetchQuestionCard(questionID: $0) }
    }

    func saveReview(questionID: UUID, chosenOptionID: UUID, result: FSRSScheduler.ReviewResult, elapsedMs: Int) throws {
        try execute(
            query: """
            INSERT INTO review_logs (id, question_id, rating, reviewed_at, elapsed_ms, chosen_option_id)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            bind: { stmt in
                sqlite3_bind_text(stmt, 1, UUID().uuidString, -1, Self.sqliteTransient)
                sqlite3_bind_text(stmt, 2, questionID.uuidString, -1, Self.sqliteTransient)
                sqlite3_bind_int(stmt, 3, Int32(result.rating.rawValue))
                sqlite3_bind_double(stmt, 4, Date().timeIntervalSince1970)
                sqlite3_bind_int(stmt, 5, Int32(elapsedMs))
                sqlite3_bind_text(stmt, 6, chosenOptionID.uuidString, -1, Self.sqliteTransient)
            }
        )

        let state = result.state
        try execute(
            query: """
            UPDATE fsrs_state
            SET status = ?, due_at = ?, stability = ?, difficulty = ?, repetitions = ?, lapses = ?, last_review_at = ?
            WHERE question_id = ?
            """,
            bind: { stmt in
                sqlite3_bind_text(stmt, 1, state.status.rawValue, -1, Self.sqliteTransient)
                sqlite3_bind_double(stmt, 2, state.dueAt.timeIntervalSince1970)
                sqlite3_bind_double(stmt, 3, state.stability)
                sqlite3_bind_double(stmt, 4, state.difficulty)
                sqlite3_bind_int(stmt, 5, Int32(state.repetitions))
                sqlite3_bind_int(stmt, 6, Int32(state.lapses))
                if let last = state.lastReviewAt {
                    sqlite3_bind_double(stmt, 7, last.timeIntervalSince1970)
                } else {
                    sqlite3_bind_null(stmt, 7)
                }
                sqlite3_bind_text(stmt, 8, questionID.uuidString, -1, Self.sqliteTransient)
            }
        )
    }

    func loadSettings() throws -> StudySettings {
        var settings = StudySettings.default
        let rows = try readSettings()
        if let value = rows["new_cards_per_day"], let parsed = Int(value) {
            settings.newCardsPerDay = parsed
        }
        if let value = rows["max_reviews_per_day"], let parsed = Int(value) {
            settings.maxReviewsPerDay = parsed
        }
        if let value = rows["show_easy_button"] {
            settings.showEasyButton = value == "1"
        }
        if let value = rows["ai_explanations_enabled"] {
            settings.aiExplanationsEnabled = value == "1"
        }
        if let value = rows["openrouter_model"], !value.isEmpty {
            settings.openRouterModel = value
        }
        return settings
    }

    func saveSettings(_ settings: StudySettings) throws {
        try upsertSetting(key: "new_cards_per_day", value: String(settings.newCardsPerDay))
        try upsertSetting(key: "max_reviews_per_day", value: String(settings.maxReviewsPerDay))
        try upsertSetting(key: "show_easy_button", value: settings.showEasyButton ? "1" : "0")
        try upsertSetting(key: "ai_explanations_enabled", value: settings.aiExplanationsEnabled ? "1" : "0")
        try upsertSetting(key: "openrouter_model", value: settings.openRouterModel)
    }

    func searchRules(query: String, limit: Int) throws -> [LocalRuleChunk] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            db,
            "SELECT source, title, chunk_text FROM rules_chunks WHERE rules_chunks MATCH ? LIMIT ?",
            -1,
            &statement,
            nil
        ) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }

        let match = normalizedFTSQuery(trimmed)
        sqlite3_bind_text(statement, 1, match, -1, Self.sqliteTransient)
        sqlite3_bind_int(statement, 2, Int32(limit))

        var chunks: [LocalRuleChunk] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let source = stringColumn(statement, index: 0) ?? "ПДД"
            let title = stringColumn(statement, index: 1) ?? "Норма"
            let text = stringColumn(statement, index: 2) ?? ""
            chunks.append(LocalRuleChunk(source: source, title: title, text: text))
        }
        return chunks
    }

    func upsertRuleChunks(_ chunks: [LocalRuleChunk], source: String = "custom") throws {
        guard !chunks.isEmpty else { return }
        for (index, chunk) in chunks.enumerated() {
            try execute(
                query: "INSERT INTO rules_chunks (chunk_id, source, title, chunk_text) VALUES (?, ?, ?, ?)",
                bind: { stmt in
                    sqlite3_bind_text(stmt, 1, "\(source)-\(index)-\(UUID().uuidString)", -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 2, chunk.source, -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 3, chunk.title, -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 4, chunk.text, -1, Self.sqliteTransient)
                }
            )
        }
    }

    func cachedExplanation(questionID: UUID, chosenOptionID: UUID) throws -> String? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            db,
            "SELECT explanation FROM ai_explanations_cache WHERE question_id = ? AND chosen_option_id = ?",
            -1,
            &statement,
            nil
        ) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, questionID.uuidString, -1, Self.sqliteTransient)
        sqlite3_bind_text(statement, 2, chosenOptionID.uuidString, -1, Self.sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return stringColumn(statement, index: 0)
    }

    func cacheExplanation(questionID: UUID, chosenOptionID: UUID, explanation: String) throws {
        try execute(
            query: """
            INSERT INTO ai_explanations_cache (question_id, chosen_option_id, explanation, created_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(question_id, chosen_option_id)
            DO UPDATE SET explanation = excluded.explanation, created_at = excluded.created_at
            """,
            bind: { stmt in
                sqlite3_bind_text(stmt, 1, questionID.uuidString, -1, Self.sqliteTransient)
                sqlite3_bind_text(stmt, 2, chosenOptionID.uuidString, -1, Self.sqliteTransient)
                sqlite3_bind_text(stmt, 3, explanation, -1, Self.sqliteTransient)
                sqlite3_bind_double(stmt, 4, Date().timeIntervalSince1970)
            }
        )
    }

    // MARK: - Import

    func upsertQuestions(_ payload: [QuestionImportDTO]) throws {
        try execute(query: "BEGIN TRANSACTION")
        do {
            for item in payload {
                try upsertQuestion(item)
            }
            try execute(query: "COMMIT")
        } catch {
            _ = try? execute(query: "ROLLBACK")
            throw error
        }
    }

    func importFromExportDirectory(_ root: URL) throws {
        let questionsDir = root.appendingPathComponent("questions", isDirectory: true)
        guard FileManager.default.fileExists(atPath: questionsDir.path) else { return }

        let decoder = JSONDecoder()
        let questionFiles = try FileManager.default.contentsOfDirectory(
            at: questionsDir,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension.lowercased() == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        try execute(query: "BEGIN TRANSACTION")
        do {
            for fileURL in questionFiles {
                let data = try Data(contentsOf: fileURL)
                let dto = try decoder.decode(ExportQuestionDTO.self, from: data)
                try upsertExportQuestion(dto, exportRoot: root)
            }
            try execute(query: "COMMIT")
        } catch {
            _ = try? execute(query: "ROLLBACK")
            throw error
        }
    }

    // MARK: - Private

    private func currentSourceSignature() -> String {
        if let url = DataPackManager.resolvedURL() {
            return "export:\(url.path)"
        }
        return "asset:adrive_questions"
    }

    private func readSettingValue(for key: String) throws -> String? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT value FROM settings WHERE key = ?", -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, key, -1, Self.sqliteTransient)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return stringColumn(statement, index: 0)
    }

    private func upsertExportQuestion(_ input: ExportQuestionDTO, exportRoot: URL) throws {
        let text = input.questionText.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !input.answers.isEmpty else { return }

        let (sectionTitle, chapterTitle) = titlesFromChapterURL(input.chapterURL)
        let questionKey = "\(input.questionID)|\(input.chapterURL)|\(text)"

        let questionID: UUID
        if let existingID = try questionIDByKey(questionKey) {
            questionID = existingID
            try execute(
                query: """
                UPDATE questions
                SET text = ?, explanation = ?, image_name = ?, section_title = ?, chapter_title = ?, created_at = ?
                WHERE id = ?
                """,
                bind: { stmt in
                    self.bindNullableText(text, stmt: stmt, index: 1)
                    self.bindNullableText(input.explanation, stmt: stmt, index: 2)
                    self.bindNullableText(self.firstMediaPath(input.mediaFiles, exportRoot: exportRoot), stmt: stmt, index: 3)
                    self.bindNullableText(sectionTitle, stmt: stmt, index: 4)
                    self.bindNullableText(chapterTitle, stmt: stmt, index: 5)
                    sqlite3_bind_double(stmt, 6, Date().timeIntervalSince1970)
                    sqlite3_bind_text(stmt, 7, questionID.uuidString, -1, Self.sqliteTransient)
                }
            )
            try execute(query: "DELETE FROM answer_options WHERE question_id = ?", bind: { stmt in
                sqlite3_bind_text(stmt, 1, questionID.uuidString, -1, Self.sqliteTransient)
            })
        } else {
            questionID = deterministicUUID(seed: "q-\(input.questionID)")
            try execute(
                query: """
                INSERT INTO questions (
                    id, question_key, text, explanation, image_name, section_title, chapter_title, correct_option_id, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                bind: { stmt in
                    sqlite3_bind_text(stmt, 1, questionID.uuidString, -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 2, questionKey, -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 3, text, -1, Self.sqliteTransient)
                    self.bindNullableText(input.explanation, stmt: stmt, index: 4)
                    self.bindNullableText(self.firstMediaPath(input.mediaFiles, exportRoot: exportRoot), stmt: stmt, index: 5)
                    self.bindNullableText(sectionTitle, stmt: stmt, index: 6)
                    self.bindNullableText(chapterTitle, stmt: stmt, index: 7)
                    sqlite3_bind_text(stmt, 8, "", -1, Self.sqliteTransient)
                    sqlite3_bind_double(stmt, 9, Date().timeIntervalSince1970)
                }
            )

            try execute(
                query: """
                INSERT INTO fsrs_state (
                    question_id, status, due_at, stability, difficulty, repetitions, lapses, last_review_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                bind: { stmt in
                    sqlite3_bind_text(stmt, 1, questionID.uuidString, -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 2, FSRSState.fresh.status.rawValue, -1, Self.sqliteTransient)
                    sqlite3_bind_double(stmt, 3, FSRSState.fresh.dueAt.timeIntervalSince1970)
                    sqlite3_bind_double(stmt, 4, FSRSState.fresh.stability)
                    sqlite3_bind_double(stmt, 5, FSRSState.fresh.difficulty)
                    sqlite3_bind_int(stmt, 6, Int32(FSRSState.fresh.repetitions))
                    sqlite3_bind_int(stmt, 7, Int32(FSRSState.fresh.lapses))
                    sqlite3_bind_null(stmt, 8)
                }
            )
        }

        var correctOptionID: UUID?
        for (index, answer) in input.answers.enumerated() {
            let optionID = deterministicUUID(seed: "a-\(answer.answerID)")
            let normalized = answer.text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            let isCorrect = input.correctAnswerIDs.contains(answer.answerID) || answer.isCorrect
            if isCorrect {
                correctOptionID = optionID
            }

            try execute(
                query: """
                INSERT INTO answer_options (id, question_id, text, position, is_correct)
                VALUES (?, ?, ?, ?, ?)
                """,
                bind: { stmt in
                    sqlite3_bind_text(stmt, 1, optionID.uuidString, -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 2, questionID.uuidString, -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 3, normalized, -1, Self.sqliteTransient)
                    sqlite3_bind_int(stmt, 4, Int32(index))
                    sqlite3_bind_int(stmt, 5, isCorrect ? 1 : 0)
                }
            )
        }

        if let correctOptionID {
            try execute(
                query: "UPDATE questions SET correct_option_id = ? WHERE id = ?",
                bind: { stmt in
                    sqlite3_bind_text(stmt, 1, correctOptionID.uuidString, -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 2, questionID.uuidString, -1, Self.sqliteTransient)
                }
            )
        }
    }

    private func titlesFromChapterURL(_ url: String) -> (String, String) {
        let parts = url.split(separator: "/").map(String.init)
        guard parts.count >= 6 else { return ("ПДД РБ", "Глава") }
        let subject = parts[2]
        let theme = parts[3]
        let chapter = parts[4]
        let leaf = parts[5]
        return ("Предмет \(subject) / Тема \(theme)", "Раздел \(chapter) / Блок \(leaf)")
    }

    private func deterministicUUID(seed: String) -> UUID {
        let digest = Insecure.MD5.hash(data: Data(seed.utf8))
        let bytes = Array(digest)
        let uuidString = String(format: "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
                                bytes[0], bytes[1], bytes[2], bytes[3],
                                bytes[4], bytes[5],
                                bytes[6], bytes[7],
                                bytes[8], bytes[9],
                                bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])
        return UUID(uuidString: uuidString) ?? UUID()
    }

    private func firstMediaPath(_ mediaFiles: [String], exportRoot: URL) -> String? {
        guard let first = mediaFiles.first(where: { !$0.lowercased().hasSuffix(".svg") }) else { return nil }
        return exportRoot.appendingPathComponent(first).path
    }

    private func openDatabase() throws {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            throw DatabaseError.executeFailed(errorMessage())
        }
    }

    private func setupSchema() throws {
        let currentVersion = try count(query: "PRAGMA user_version")
        if currentVersion != SoloSchema.version {
            try resetSchema()
        }
        try seedDefaultSettingsIfMissing()
    }

    private func resetSchema() throws {
        try execute(query: "DROP TABLE IF EXISTS questions")
        try execute(query: "DROP TABLE IF EXISTS answer_options")
        try execute(query: "DROP TABLE IF EXISTS review_logs")
        try execute(query: "DROP TABLE IF EXISTS fsrs_state")
        try execute(query: "DROP TABLE IF EXISTS settings")
        try execute(query: "DROP TABLE IF EXISTS ai_explanations_cache")
        try execute(query: "DROP TABLE IF EXISTS rules_chunks")

        try execute(
            query: """
            CREATE TABLE questions (
                id TEXT PRIMARY KEY,
                question_key TEXT NOT NULL UNIQUE,
                text TEXT NOT NULL,
                explanation TEXT,
                image_name TEXT,
                section_title TEXT,
                chapter_title TEXT,
                correct_option_id TEXT NOT NULL,
                created_at REAL NOT NULL
            )
            """
        )

        try execute(
            query: """
            CREATE TABLE answer_options (
                id TEXT PRIMARY KEY,
                question_id TEXT NOT NULL,
                text TEXT NOT NULL,
                position INTEGER NOT NULL,
                is_correct INTEGER NOT NULL,
                FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
            )
            """
        )

        try execute(
            query: """
            CREATE TABLE fsrs_state (
                question_id TEXT PRIMARY KEY,
                status TEXT NOT NULL,
                due_at REAL NOT NULL,
                stability REAL NOT NULL,
                difficulty REAL NOT NULL,
                repetitions INTEGER NOT NULL,
                lapses INTEGER NOT NULL,
                last_review_at REAL,
                FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
            )
            """
        )

        try execute(
            query: """
            CREATE TABLE review_logs (
                id TEXT PRIMARY KEY,
                question_id TEXT NOT NULL,
                rating INTEGER NOT NULL,
                reviewed_at REAL NOT NULL,
                elapsed_ms INTEGER NOT NULL,
                chosen_option_id TEXT NOT NULL,
                FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
            )
            """
        )

        try execute(query: "CREATE INDEX idx_fsrs_due ON fsrs_state(due_at)")

        try execute(
            query: """
            CREATE TABLE settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
            """
        )

        try execute(
            query: """
            CREATE TABLE ai_explanations_cache (
                question_id TEXT NOT NULL,
                chosen_option_id TEXT NOT NULL,
                explanation TEXT NOT NULL,
                created_at REAL NOT NULL,
                PRIMARY KEY (question_id, chosen_option_id)
            )
            """
        )

        try execute(
            query: """
            CREATE VIRTUAL TABLE rules_chunks USING fts5(
                chunk_id UNINDEXED,
                source UNINDEXED,
                title,
                chunk_text
            )
            """
        )

        try execute(query: "PRAGMA user_version = \(SoloSchema.version)")
    }

    private func upsertQuestion(_ input: QuestionImportDTO) throws {
        let normalizedText = input.question.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return }

        let normalizedParts = input.hierarchy
            .split(separator: "➔")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let section = normalizedParts.dropLast().dropLast().last ?? "ПДД РБ"
        let chapter = normalizedParts.dropLast().last ?? "Раздел"

        let options = input.options.enumerated().map { idx, raw in
            (idx, self.cleanOptionText(raw.replacingOccurrences(of: "\n", with: " ")))
        }

        guard !options.isEmpty else { return }
        let safeCorrectIndex = min(max(0, input.correctIndex), options.count - 1)
        let questionKey = "\(normalizedText)|\(chapter)"

        let questionID: UUID
        if let existingID = try questionIDByKey(questionKey) {
            questionID = existingID
            try execute(
                query: """
                UPDATE questions
                SET text = ?, explanation = ?, image_name = ?, section_title = ?, chapter_title = ?, created_at = ?
                WHERE id = ?
                """,
                bind: { stmt in
                    sqlite3_bind_text(stmt, 1, normalizedText, -1, Self.sqliteTransient)
                    self.bindNullableText(input.explanation?.replacingOccurrences(of: "\n", with: " "), stmt: stmt, index: 2)
                    self.bindNullableText(self.normalizedImageName(input.image), stmt: stmt, index: 3)
                    self.bindNullableText(section, stmt: stmt, index: 4)
                    self.bindNullableText(chapter, stmt: stmt, index: 5)
                    sqlite3_bind_double(stmt, 6, Date().timeIntervalSince1970)
                    sqlite3_bind_text(stmt, 7, questionID.uuidString, -1, Self.sqliteTransient)
                }
            )
            try execute(query: "DELETE FROM answer_options WHERE question_id = ?", bind: { stmt in
                sqlite3_bind_text(stmt, 1, questionID.uuidString, -1, Self.sqliteTransient)
            })
        } else {
            questionID = UUID()
            try execute(
                query: """
                INSERT INTO questions (
                    id, question_key, text, explanation, image_name, section_title, chapter_title, correct_option_id, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                bind: { stmt in
                    sqlite3_bind_text(stmt, 1, questionID.uuidString, -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 2, questionKey, -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 3, normalizedText, -1, Self.sqliteTransient)
                    self.bindNullableText(input.explanation?.replacingOccurrences(of: "\n", with: " "), stmt: stmt, index: 4)
                    self.bindNullableText(self.normalizedImageName(input.image), stmt: stmt, index: 5)
                    self.bindNullableText(section, stmt: stmt, index: 6)
                    self.bindNullableText(chapter, stmt: stmt, index: 7)
                    sqlite3_bind_text(stmt, 8, "", -1, Self.sqliteTransient)
                    sqlite3_bind_double(stmt, 9, Date().timeIntervalSince1970)
                }
            )

            try execute(
                query: """
                INSERT INTO fsrs_state (
                    question_id, status, due_at, stability, difficulty, repetitions, lapses, last_review_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                bind: { stmt in
                    sqlite3_bind_text(stmt, 1, questionID.uuidString, -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 2, FSRSState.fresh.status.rawValue, -1, Self.sqliteTransient)
                    sqlite3_bind_double(stmt, 3, FSRSState.fresh.dueAt.timeIntervalSince1970)
                    sqlite3_bind_double(stmt, 4, FSRSState.fresh.stability)
                    sqlite3_bind_double(stmt, 5, FSRSState.fresh.difficulty)
                    sqlite3_bind_int(stmt, 6, Int32(FSRSState.fresh.repetitions))
                    sqlite3_bind_int(stmt, 7, Int32(FSRSState.fresh.lapses))
                    sqlite3_bind_null(stmt, 8)
                }
            )
        }

        var correctOptionID: UUID?
        for (idx, text) in options {
            let optionID = UUID()
            let isCorrect = idx == safeCorrectIndex
            if isCorrect { correctOptionID = optionID }
            try execute(
                query: """
                INSERT INTO answer_options (id, question_id, text, position, is_correct)
                VALUES (?, ?, ?, ?, ?)
                """,
                bind: { stmt in
                    sqlite3_bind_text(stmt, 1, optionID.uuidString, -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 2, questionID.uuidString, -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 3, text, -1, Self.sqliteTransient)
                    sqlite3_bind_int(stmt, 4, Int32(idx))
                    sqlite3_bind_int(stmt, 5, isCorrect ? 1 : 0)
                }
            )
        }

        if let correctOptionID {
            try execute(
                query: "UPDATE questions SET correct_option_id = ? WHERE id = ?",
                bind: { stmt in
                    sqlite3_bind_text(stmt, 1, correctOptionID.uuidString, -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 2, questionID.uuidString, -1, Self.sqliteTransient)
                }
            )
        }
    }

    private func fetchQuestionCard(questionID: UUID) throws -> QuestionCard? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            db,
            """
            SELECT q.id, q.text, q.explanation, q.image_name, q.section_title, q.chapter_title, q.correct_option_id,
                   s.status, s.due_at, s.stability, s.difficulty, s.repetitions, s.lapses, s.last_review_at
            FROM questions q
            JOIN fsrs_state s ON s.question_id = q.id
            WHERE q.id = ?
            """,
            -1,
            &statement,
            nil
        ) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, questionID.uuidString, -1, Self.sqliteTransient)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }

        guard
            let idText = stringColumn(statement, index: 0),
            let qid = UUID(uuidString: idText),
            let text = stringColumn(statement, index: 1),
            let correctIDText = stringColumn(statement, index: 6),
            let correctID = UUID(uuidString: correctIDText),
            let statusRaw = stringColumn(statement, index: 7),
            let status = FSRSStatus(rawValue: statusRaw)
        else {
            return nil
        }

        let options = try fetchOptions(questionID: qid)
        let question = Question(
            id: qid,
            text: text,
            explanation: stringColumn(statement, index: 2),
            imageName: stringColumn(statement, index: 3),
            sectionTitle: stringColumn(statement, index: 4),
            chapterTitle: stringColumn(statement, index: 5),
            correctOptionID: correctID,
            options: options
        )

        let dueAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 8))
        let lastReviewAt: Date?
        if sqlite3_column_type(statement, 13) == SQLITE_NULL {
            lastReviewAt = nil
        } else {
            lastReviewAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 13))
        }

        let state = FSRSState(
            status: status,
            dueAt: dueAt,
            stability: sqlite3_column_double(statement, 9),
            difficulty: sqlite3_column_double(statement, 10),
            repetitions: Int(sqlite3_column_int(statement, 11)),
            lapses: Int(sqlite3_column_int(statement, 12)),
            lastReviewAt: lastReviewAt
        )

        return QuestionCard(question: question, state: state)
    }

    private func fetchOptions(questionID: UUID) throws -> [AnswerOption] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            db,
            "SELECT id, text, position, is_correct FROM answer_options WHERE question_id = ? ORDER BY position ASC",
            -1,
            &statement,
            nil
        ) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, questionID.uuidString, -1, Self.sqliteTransient)

        var options: [AnswerOption] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let idText = stringColumn(statement, index: 0),
                let id = UUID(uuidString: idText),
                let text = stringColumn(statement, index: 1)
            else { continue }
            let position = Int(sqlite3_column_int(statement, 2))
            let isCorrect = sqlite3_column_int(statement, 3) == 1
            options.append(AnswerOption(id: id, text: text, position: position, isCorrect: isCorrect))
        }
        return options
    }

    private func seedRulesChunksFromQuestions(limit: Int) throws {
        guard try count(query: "SELECT COUNT(*) FROM rules_chunks") == 0 else { return }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            db,
            "SELECT id, chapter_title, section_title, explanation, text FROM questions LIMIT ?",
            -1,
            &statement,
            nil
        ) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(limit))

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let qid = stringColumn(statement, index: 0) else { continue }
            let chapter = stringColumn(statement, index: 1) ?? "Глава"
            let section = stringColumn(statement, index: 2) ?? "ПДД РБ"
            let explanation = stringColumn(statement, index: 3) ?? ""
            let question = stringColumn(statement, index: 4) ?? ""

            let body = explanation.isEmpty ? question : explanation
            guard !body.isEmpty else { continue }

            try execute(
                query: "INSERT INTO rules_chunks (chunk_id, source, title, chunk_text) VALUES (?, ?, ?, ?)",
                bind: { stmt in
                    sqlite3_bind_text(stmt, 1, "q-\(qid)", -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 2, section, -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 3, chapter, -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 4, body, -1, Self.sqliteTransient)
                }
            )
        }
    }

    private func seedRulesChunksFromBundleIfAvailable() throws {
        guard let url = Bundle.main.url(forResource: "pdd_rules", withExtension: "txt") else { return }
        let raw = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        guard !raw.isEmpty else { return }

        let blocks = raw
            .split(separator: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for (index, block) in blocks.enumerated() {
            try execute(
                query: "INSERT INTO rules_chunks (chunk_id, source, title, chunk_text) VALUES (?, ?, ?, ?)",
                bind: { stmt in
                    sqlite3_bind_text(stmt, 1, "rules-\(index)", -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 2, "ПДД РБ", -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 3, "Официальный текст", -1, Self.sqliteTransient)
                    sqlite3_bind_text(stmt, 4, block, -1, Self.sqliteTransient)
                }
            )
        }
    }

    private func seedDefaultSettingsIfMissing() throws {
        let defaults = StudySettings.default
        if try readSettings().isEmpty {
            try saveSettings(defaults)
        }
    }

    private func readSettings() throws -> [String: String] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT key, value FROM settings", -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }

        var rows: [String: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let key = stringColumn(statement, index: 0), let value = stringColumn(statement, index: 1) else {
                continue
            }
            rows[key] = value
        }
        return rows
    }

    private func upsertSetting(key: String, value: String) throws {
        try execute(
            query: """
            INSERT INTO settings (key, value) VALUES (?, ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value
            """,
            bind: { stmt in
                sqlite3_bind_text(stmt, 1, key, -1, Self.sqliteTransient)
                sqlite3_bind_text(stmt, 2, value, -1, Self.sqliteTransient)
            }
        )
    }

    private func fetchQuestionIDs(query: String, bind: (OpaquePointer?) -> Void) throws -> [UUID] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }
        bind(statement)

        var ids: [UUID] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let text = stringColumn(statement, index: 0), let id = UUID(uuidString: text) {
                ids.append(id)
            }
        }
        return ids
    }

    private func questionIDByKey(_ key: String) throws -> UUID? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT id FROM questions WHERE question_key = ?", -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, key, -1, Self.sqliteTransient)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        guard let text = stringColumn(statement, index: 0) else { return nil }
        return UUID(uuidString: text)
    }

    private func normalizedImageName(_ source: String?) -> String? {
        guard let source, !source.isEmpty else { return nil }
        let filename = source.replacingOccurrences(of: "images/", with: "")
        let noExt = filename.components(separatedBy: ".").dropLast().joined(separator: ".")
        return noExt.isEmpty ? filename : noExt
    }

    private func cleanOptionText(_ text: String) -> String {
        let pattern = #"^\s*\d+[\.\)\-\s/]+\s*"#
        return text
            .replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedFTSQuery(_ query: String) -> String {
        query
            .split(separator: " ")
            .map { "\($0)*" }
            .joined(separator: " ")
    }

    private func bindNullableText(_ value: String?, stmt: OpaquePointer?, index: Int32) {
        if let value, !value.isEmpty {
            sqlite3_bind_text(stmt, index, value, -1, Self.sqliteTransient)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func execute(query: String, bind: ((OpaquePointer?) -> Void)? = nil) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }

        bind?(statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executeFailed(errorMessage())
        }
    }

    private func count(query: String) throws -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func stringColumn(_ stmt: OpaquePointer?, index: Int32) -> String? {
        guard let cString = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cString)
    }

    private func errorMessage() -> String {
        guard let db, let cError = sqlite3_errmsg(db) else { return "Unknown SQLite error" }
        return String(cString: cError)
    }
}

enum DatabaseError: Error, LocalizedError {
    case prepareFailed(String)
    case executeFailed(String)

    var errorDescription: String? {
        switch self {
        case .prepareFailed(let msg):
            return "SQLite prepare failed: \(msg)"
        case .executeFailed(let msg):
            return "SQLite execute failed: \(msg)"
        }
    }
}
