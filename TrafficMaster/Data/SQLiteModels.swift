//
//  SQLiteModels.swift
//  TrafficMaster
//
//  Data Layer - SQLite Database Models
//

import Foundation

// MARK: - Revlog (Журнал повторений)

/// Запись о прошедшем повторении (append-only)
struct Revlog: Codable {
    let id: UUID
    let cardId: UUID
    let reviewDatetime: Date
    let grade: Int // 1 = wrong, 3 = correct
    let timeTaken: Int // milliseconds
    let preStability: Double
    let preDifficulty: Double
}

// MARK: - Database Schema Constants

enum DatabaseSchema {
    static let version = 2 // v2: Using unified questions table
    
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
        next_review_date REAL NOT NULL
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
    CREATE INDEX IF NOT EXISTS idx_revlogs_card_id ON revlogs(card_id);
    """
}
