import Combine
import Foundation
import SwiftUI
import UIKit

class NotebookLMQuizStore: ObservableObject {
    static let shared = NotebookLMQuizStore()
    
    @Published var quizzes: [NotebookLMQuiz] = []
    
    init() {
        loadQuizzes()
    }
    
    func loadQuizzes() {
        guard let asset = NSDataAsset(name: "notebooklm_quizzes") else {
            print("Failed to find 'notebooklm_quizzes' in Assets.")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let loadedQuizzes = try decoder.decode([NotebookLMQuiz].self, from: asset.data)
            self.quizzes = loadedQuizzes.shuffled()
            print("Successfully loaded \(loadedQuizzes.count) NotebookLM quizzes.")
        } catch {
            print("Failed to decode NotebookLM quizzes: \(error)")
        }
    }
}
