//
//  SQLiteModels.swift
//  TrafficMaster
//
//  Data Layer - SQLite Database Models
//

import Foundation

enum ReviewRating: Int, Codable, CaseIterable, Sendable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4
}

// MARK: - Revlog (Журнал повторений)

/// Запись о прошедшем повторении (append-only)
struct Revlog: Codable {
    let id: UUID
    let cardId: UUID
    let reviewDatetime: Date
    let grade: Int // 1...4 (AGAIN/HARD/GOOD/EASY)
    let timeTaken: Int // milliseconds
    let preStability: Double
    let preDifficulty: Double
}

/// Локальное событие для синка ответов с backend (offline-first outbox)
struct SyncReviewEvent: Codable, Identifiable, Sendable {
    let id: UUID
    let cardId: UUID
    let selectedOptionID: UUID?
    let rating: ReviewRating
    let answeredAt: Date
    let timeSpentMs: Int
    let createdAt: Date
}

// MARK: - Database Schema Constants

enum DatabaseSchema {
    static let version = 5 // v5: align local card progress with backend SM-2 state
    
    static let createQuestionsTable = """
    CREATE TABLE IF NOT EXISTS questions (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        options TEXT NOT NULL,
        correct_answer_index INTEGER NOT NULL,
        explanation TEXT,
        image_name TEXT,
        section_title TEXT,
        chapter_title TEXT,
        stability REAL NOT NULL DEFAULT 0.0,
        difficulty REAL NOT NULL DEFAULT 5.0,
        retrievability REAL NOT NULL DEFAULT 1.0,
        repetitions INTEGER NOT NULL DEFAULT 0,
        interval INTEGER NOT NULL DEFAULT 1,
        easiness_factor REAL NOT NULL DEFAULT 2.5,
        next_review_date REAL NOT NULL,
        answer_options_json TEXT,
        backend_card_id TEXT,
        backend_deck_id TEXT,
        backend_card_progress_id TEXT,
        sm2_state TEXT NOT NULL DEFAULT 'new',
        seen_at REAL
    )
    """
    
    static let createRevlogsTable = """
    CREATE TABLE IF NOT EXISTS revlogs (
        id TEXT PRIMARY KEY,
        card_id TEXT NOT NULL,
        review_datetime REAL NOT NULL,
        grade INTEGER NOT NULL,
        time_taken INTEGER NOT NULL,
        pre_stability REAL NOT NULL,
        pre_difficulty REAL NOT NULL,
        FOREIGN KEY (card_id) REFERENCES questions(id) ON DELETE CASCADE
    )
    """
    
    static let createIndexes = """
    CREATE INDEX IF NOT EXISTS idx_questions_next_review ON questions(next_review_date);
    CREATE INDEX IF NOT EXISTS idx_questions_chapter ON questions(chapter_title);
    CREATE INDEX IF NOT EXISTS idx_questions_backend_card_id ON questions(backend_card_id);
    CREATE INDEX IF NOT EXISTS idx_revlogs_card_id ON revlogs(card_id);
    CREATE INDEX IF NOT EXISTS idx_sync_outbox_created_at ON sync_outbox(created_at);
    """
    
    static let createSyncOutboxTable = """
    CREATE TABLE IF NOT EXISTS sync_outbox (
        id TEXT PRIMARY KEY,
        card_id TEXT NOT NULL,
        selected_option_id TEXT,
        rating INTEGER NOT NULL,
        answered_at REAL NOT NULL,
        time_spent_ms INTEGER NOT NULL DEFAULT 0,
        created_at REAL NOT NULL,
        synced_at REAL,
        FOREIGN KEY (card_id) REFERENCES questions(id) ON DELETE CASCADE
    )
    """
}
