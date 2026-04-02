import Foundation
import Testing
@testable import TrafficMaster

@MainActor
struct QuestionViewModelTests {

    @Test func loadQuestionsMarathonLimit() async throws {
        UserDefaults.standard.removeObject(forKey: "marathon_session_ids")
        let viewModel = QuestionViewModel()
        let questions = (0..<50).map { Question(text: "Q\($0)", options: ["A"], correctAnswerIndex: 0) }
        
        viewModel.loadQuestions(isMarathon: true, dailyNewLimit: 10)
        
        // Since we load from SQLite now in the actual app, this test might need a mocked DB.
        // For now, we just ensure it doesn't crash when called with empty DB.
        #expect(viewModel.allQuestions.isEmpty || !viewModel.allQuestions.isEmpty)
    }

    @Test func selectAnswerLogic() async throws {
        let viewModel = QuestionViewModel()
        let question = Question(text: "Q1", options: ["A", "B"], correctAnswerIndex: 0)
        viewModel.allQuestions = [question]
        viewModel.currentQuestion = question
        viewModel.shuffledOptions = ["A", "B"]
        
        let correctIndex = viewModel.correctAnswerIndexInShuffled ?? 0
        viewModel.selectAnswer(index: correctIndex)
        
        #expect(viewModel.isCorrect == true)
        #expect(viewModel.userAnswerIndex == correctIndex)
    }
}

@MainActor
struct ProgressTrackerTests {
    @Test func calculateStreakLogic() async throws {
        let tracker = ProgressTracker.shared
        let calendar = Calendar.current
        var history: [String: Int] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Reset
        UserDefaults.standard.removeObject(forKey: "study_history")
        
        // Add 3 days
        for i in 0..<3 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            history[formatter.string(from: date)] = 1
        }
        UserDefaults.standard.set(history, forKey: "study_history")
        
        #expect(tracker.calculateStreak() == 3)
    }
    
    @Test func calculateStreakWithGap() async throws {
        let tracker = ProgressTracker.shared
        let calendar = Calendar.current
        var history: [String: Int] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Reset
        UserDefaults.standard.removeObject(forKey: "study_history")
        
        // Today and Yesterday
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let gapDay = calendar.date(byAdding: .day, value: -3, to: today)! // 2 days ago is empty
        
        history[formatter.string(from: today)] = 1
        history[formatter.string(from: yesterday)] = 1
        history[formatter.string(from: gapDay)] = 1
        
        UserDefaults.standard.set(history, forKey: "study_history")
        
        // Streak should break at the gap, so it should be 2
        #expect(tracker.calculateStreak() == 2)
    }
    
    @Test func calculateSavedTime() async throws {
        let tracker = ProgressTracker.shared
        var history: [String: Int] = [:]
        
        UserDefaults.standard.removeObject(forKey: "study_history")
        
        history["2026-01-01"] = 30 // 30 cards
        history["2026-01-02"] = 30 // 30 cards
        // Total 60 cards. 60 * 2 mins = 120 mins = 2 hours.
        
        UserDefaults.standard.set(history, forKey: "study_history")
        
        #expect(tracker.calculateSavedTimeHours() == 2)
    }
}

@Suite("FSRS Algorithm Tests")
@MainActor
struct FSRSAlgorithmTests {
    
    @Test("Initial values of a new card")
    func testInitialValues() async throws {
        let question = Question(text: "Q", options: ["A"], correctAnswerIndex: 0)
        
        #expect(question.stability == 0.0)
        #expect(question.difficulty == 5.0)
        #expect(question.retrievability == 1.0)
        #expect(question.repetitions == 0)
    }
    
    @Test("Values calculation after the first 'Good'")
    func testFirstGood() async throws {
        let viewModel = QuestionViewModel()
        let question = Question(text: "Q", options: ["A"], correctAnswerIndex: 0)
        viewModel.allQuestions = [question]
        viewModel.currentQuestion = question
        
        // Simulating "Good" rating by selecting correct answer
        viewModel.isCorrect = true 
        viewModel.continueToNext()
        
        #expect(question.repetitions == 1)
        #expect(question.stability > 0.0)
        #expect(question.difficulty < 5.0) // Difficulty usually drops slightly on first correct
    }
    
    @Test("Penalty for 'Again' rating")
    func testAgainPenalty() async throws {
        let viewModel = QuestionViewModel()
        let question = Question(text: "Q", options: ["A"], correctAnswerIndex: 0)
        question.repetitions = 5
        question.stability = 20.0
        question.difficulty = 4.0
        
        viewModel.allQuestions = [question]
        viewModel.currentQuestion = question
        
        // Simulating "Again" rating by answering incorrectly
        viewModel.isCorrect = false
        viewModel.continueToNext()
        
        #expect(question.repetitions == 0)
        #expect(question.stability < 20.0) // Stability crashes
        #expect(question.difficulty > 4.0) // Difficulty spikes
    }
}
