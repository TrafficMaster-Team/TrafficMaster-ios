@testable import TrafficMaster
import XCTest

final class ProgressTrackerTests: XCTestCase {
    var tracker: ProgressTracker!
    
    override func setUp() {
        super.setUp()
        tracker = ProgressTracker.shared
        // Clear history for testing if possible, but it uses UserDefaults.standard
        UserDefaults.standard.removeObject(forKey: "study_history")
    }
    
    func testLogCardStudied() {
        tracker.logCardStudied()
        let history = tracker.getHistory()
        XCTAssertFalse(history.isEmpty)
        
        let today = DateFormatter()
        today.dateFormat = "yyyy-MM-dd"
        let dateStr = today.string(from: Date())
        XCTAssertEqual(history[dateStr], 1)
    }
    
    func testCalculateStreak() {
        let calendar = Calendar.current
        var history: [String: Int] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Add 3 days of activity
        for i in 0..<3 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            history[formatter.string(from: date)] = 1
        }
        
        UserDefaults.standard.set(history, forKey: "study_history")
        
        let streak = tracker.calculateStreak()
        XCTAssertEqual(streak, 3)
    }
    
    func testCalculateSavedTime() {
        var history: [String: Int] = [:]
        let today = DateFormatter()
        today.dateFormat = "yyyy-MM-dd"
        history[today.string(from: Date())] = 60 // 60 cards
        
        UserDefaults.standard.set(history, forKey: "study_history")
        
        // 60 cards * 2 min = 120 min = 2 hours
        let savedTime = tracker.calculateSavedTimeHours()
        XCTAssertEqual(savedTime, 2)
    }
}
