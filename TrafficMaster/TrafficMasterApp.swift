//
//  TrafficMasterApp.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import SwiftUI
import UIKit

struct QuestionImportDTO: Codable {
    let hierarchy: String
    let question: String
    let image: String?
    let options: [String]
    let correctIndex: Int
    let correctText: String
    let explanation: String?
    
    enum CodingKeys: String, CodingKey {
        case hierarchy, question, image, options, explanation
        case correctIndex = "correct_index"
        case correctText = "correct_text"
    }
}

@main
struct TrafficMasterApp: App {
    // Current DB Version
    static let dbVersion = 10 // v10: Clean options double numbering correctly

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Start import in background if needed
                    Task.detached(priority: .background) {
                        await importDataIfNeeded()
                    }
                }
        }
    }
    
    private func cleanOptionText(_ option: String) -> String {
        let pattern = #"^\s*\d+[\.\)\-\s/]+\s*"#
        let cleaned = option.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Optimized Background Data Import using SQLite
    private func importDataIfNeeded() async {
        let savedDBVersion = UserDefaults.standard.integer(forKey: "db_version")
        guard savedDBVersion < TrafficMasterApp.dbVersion else { 
            // Already up-to-date, but ping the UI just in case it missed the initial load
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("DatabaseImportCompleted"), object: nil)
            }
            return 
        }

        print("🚀 Starting SQLite background data import...")
        let db = DatabaseService.shared

        do {
            // 1. Fetch existing questions for matching
            let existingQuestions = try db.fetchAllQuestions()
            
            // Create a lookup dictionary
            var existingMap: [String: Question] = [:]
            for q in existingQuestions {
                let key = "\(q.text)|\(q.sectionTitle ?? "")|\(q.chapterTitle ?? "")"
                existingMap[key] = q
            }

            // 2. Load JSON from Asset Catalog
            guard let asset = NSDataAsset(name: "adrive_questions") else {
                print("❌ Failed to find 'adrive_questions' in Assets.")
                // Notify UI even on failure so it doesn't spin forever
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name("DatabaseImportCompleted"), object: nil)
                }
                return
            }

            let decoder = JSONDecoder()
            let imported = try decoder.decode([QuestionImportDTO].self, from: asset.data)

            print("📦 Processing \(imported.count) questions in SQLite...")

            // 3. Update or Insert questions
            try db.executeTransaction {
                for importQ in imported {
                    let parts = importQ.hierarchy.split(separator: "➔").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    let section = parts.count >= 3 ? String(parts[2]) : "Раздел"
                    var chapter = parts.count >= 4 ? String(parts[3]) : "Глава"
                    if parts.count >= 5 {
                        chapter += " (\(parts[4]))"
                    }

                    let cleanedText = importQ.question.replacingOccurrences(of: "\n", with: " ")
                    let key = "\(cleanedText)|\(section)|\(chapter)"
                    
                    let cleanedOptions = importQ.options.map { cleanOptionText($0.replacingOccurrences(of: "\n", with: " ")) }

                    var imageName: String?
                    if let img = importQ.image {
                        let filename = img.replacingOccurrences(of: "images/", with: "")
                        let nameWithoutExt = filename.components(separatedBy: ".").dropLast().joined(separator: ".")
                        imageName = nameWithoutExt.isEmpty ? filename : nameWithoutExt
                    }

                    if let existing = existingMap[key] {
                        // Update static content
                        existing.options = cleanedOptions
                        existing.correctAnswerIndex = importQ.correctIndex
                        existing.explanation = importQ.explanation?.replacingOccurrences(of: "\n", with: " ")
                        existing.imageName = imageName
                        existing.sectionTitle = section
                        existing.chapterTitle = chapter
                        
                        try db.saveQuestion(existing)
                    } else {
                        // Insert new
                        let newQuestion = Question(
                            text: cleanedText,
                            options: cleanedOptions,
                            correctAnswerIndex: importQ.correctIndex,
                            explanation: importQ.explanation?.replacingOccurrences(of: "\n", with: " "),
                            imageName: imageName,
                            sectionTitle: section,
                            chapterTitle: chapter
                        )
                        try db.saveQuestion(newQuestion)
                    }
                }
            }

            UserDefaults.standard.set(TrafficMasterApp.dbVersion, forKey: "db_version")
            print("🎉 Successfully finished SQLite data import.")
            
            // Notify views that the import is complete so they can reload
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("DatabaseImportCompleted"), object: nil)
            }
        } catch {
            print("❌ SQLite Import error: \(error.localizedDescription)")
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("DatabaseImportCompleted"), object: nil)
            }
        }
    }
}
