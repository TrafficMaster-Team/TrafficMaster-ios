//
//  FSRSScheduler.swift
//  TrafficMaster
//
//  Domain Layer - FSRS Algorithm Service
//  Simplified implementation based on FSRS v4 algorithm
//

import Foundation

/// Domain Layer service for FSRS spaced repetition algorithm
/// Encapsulates all FSRS logic, keeping ViewModel clean
/// 
/// Based on FSRS v4 algorithm:
/// - Uses DSR (Difficulty, Stability, Retrievability) memory model
/// - Binary grading system (Grade 1 = Wrong, Grade 3 = Correct)
/// - Target retention: 90%
class FSRSScheduler {
    
    // Default FSRS weights (trained on millions of Anki logs)
    // These are simplified default weights from FSRS v4
    private let defaultWeights: [Double] = [
        0.4072, 1.1829, 3.1262, 15.4722, 7.2102,
        0.5316, 1.0651, 1.8296, 0.1547, 0.3016,
        1.0795, 2.1197, 0.0209, 0.329, 2.6498,
        0.1546, 0.7408, 2.0196
    ]
    
    private let desiredRetention: Double = 0.9 // 90% target retention
    
    /// Represents a card's state for FSRS
    struct CardState {
        let stability: Double
        let difficulty: Double
        let lastReviewDate: Date?
        let dueDate: Date?
    }
    
    /// Grade for FSRS (binary system as per requirements)
    enum Grade: Int {
        case again = 1  // Wrong answer
        case good = 3   // Correct answer
    }
    
    /// Result of reviewing a card
    struct ReviewResult {
        let stability: Double
        let difficulty: Double
        let retrievability: Double
        let nextReviewDate: Date
        let state: CardState
    }
    
    /// Process a card review and return updated state
    /// - Parameters:
    ///   - cardState: Current state of the card
    ///   - grade: User's performance (1 = wrong, 3 = correct)
    ///   - reviewTime: When the review happened
    /// - Returns: Updated card state with new interval
    func reviewCard(
        cardState: CardState,
        grade: Grade,
        reviewTime: Date = Date()
    ) -> ReviewResult {
        let elapsedDays = daysBetween(cardState.lastReviewDate ?? reviewTime, and: reviewTime)
        
        // Calculate current retrievability
        let retrievability = calculateRetrievability(
            stability: cardState.stability,
            elapsedDays: elapsedDays
        )
        
        var newStability: Double
        var newDifficulty: Double
        
        if grade == .again {
            // Forgot the card - apply forgetting penalty
            newDifficulty = max(1.0, cardState.difficulty + 2.0)
            newStability = calculateForgettingStability(
                stability: cardState.stability,
                retrievability: retrievability
            )
        } else {
            // Remembered the card - apply learning
            newDifficulty = max(1.0, cardState.difficulty - 0.1)
            newStability = calculateRememberingStability(
                stability: cardState.stability,
                retrievability: retrievability,
                difficulty: cardState.difficulty
            )
        }
        
        // Ensure minimum stability
        newStability = max(0.1, newStability)
        
        // Calculate next review date based on stability and desired retention
        let nextReviewDate = calculateNextReviewDate(
            stability: newStability,
            from: reviewTime
        )
        
        return ReviewResult(
            stability: newStability,
            difficulty: newDifficulty,
            retrievability: retrievability,
            nextReviewDate: nextReviewDate,
            state: CardState(
                stability: newStability,
                difficulty: newDifficulty,
                lastReviewDate: reviewTime,
                dueDate: nextReviewDate
            )
        )
    }
    
    /// Get initial state for a new card (first review)
    /// - Parameters:
    ///   - grade: User's performance on first attempt
    ///   - reviewTime: When the first review happened
    /// - Returns: Initial card state
    func initialState(for grade: Grade, reviewTime: Date = Date()) -> ReviewResult {
        // Initial difficulty based on grade
        let initialDifficulty = grade == .again ? 5.0 : 3.0
        
        // Initial stability from weights
        let initialStability = grade == .again ? defaultWeights[0] : defaultWeights[1]
        
        let nextReviewDate = calculateNextReviewDate(
            stability: initialStability,
            from: reviewTime
        )
        
        return ReviewResult(
            stability: initialStability,
            difficulty: initialDifficulty,
            retrievability: 1.0, // Just learned, 100% retrievability
            nextReviewDate: nextReviewDate,
            state: CardState(
                stability: initialStability,
                difficulty: initialDifficulty,
                lastReviewDate: reviewTime,
                dueDate: nextReviewDate
            )
        )
    }
    
    // MARK: - Private FSRS Formulas
    
    /// R = (1 + S / D) ^ (-S)
    /// Where S = stability, D = elapsed days
    private func calculateRetrievability(stability: Double, elapsedDays: Double) -> Double {
        guard elapsedDays > 0 && stability > 0 else { return 1.0 }
        return pow(1.0 + stability / elapsedDays, -stability)
    }
    
    /// S' = S * (1 + R^(-1/w[5]) - 1) * w[6]
    /// Forgetting stability calculation
    private func calculateForgettingStability(stability: Double, retrievability: Double) -> Double {
        let w5 = defaultWeights[5]
        let w6 = defaultWeights[6]
        guard retrievability > 0 && retrievability < 1 else { return stability * 0.5 }
        return stability * (1 + pow(retrievability, -1/w5) - 1) * w6
    }
    
    /// S' = S * (1 + exp(w[7]) * (11-D) * S^(-w[8]) * (exp((1-R)*w[9])-1))
    /// Remembering stability calculation
    private func calculateRememberingStability(stability: Double, retrievability: Double, difficulty: Double) -> Double {
        let w7 = defaultWeights[7]
        let w8 = defaultWeights[8]
        let w9 = defaultWeights[9]
        
        let difficultyFactor = 11.0 - difficulty
        let stabilityFactor = pow(stability, -w8)
        let retrievabilityFactor = exp((1 - retrievability) * w9) - 1
        
        return stability * (1 + exp(w7) * difficultyFactor * stabilityFactor * retrievabilityFactor)
    }
    
    /// I = S * ln(R) / ln(0.5)
    /// Calculate next interval in days from stability
    private func calculateNextReviewDate(stability: Double, from date: Date) -> Date {
        // For 90% retention: interval ≈ stability * ln(0.9) / ln(0.5) ≈ stability * 0.152
        let intervalDays = max(1, Int(round(stability * 0.152)))
        return Calendar.current.date(byAdding: .day, value: intervalDays, to: date) ?? date
    }
    
    private func daysBetween(_ start: Date, and end: Date) -> Double {
        return end.timeIntervalSince(start) / (24 * 60 * 60)
    }
}
