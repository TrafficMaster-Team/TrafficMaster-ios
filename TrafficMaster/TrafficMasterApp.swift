//
//  TrafficMasterApp.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
    static let dbVersion = 11 // v11: Normalize chapters/applications to official RB traffic rules titles

    private static let chapterTitles: [Int: String] = [
        1: "Глава 1. Общие положения.",
        2: "Глава 2. Общие права и обязанности участников дорожного движения.",
        3: "Глава 3. Права и обязанности водителей.",
        4: "Глава 4. Права и обязанности пешеходов.",
        5: "Глава 5. Обязанности пассажиров.",
        6: "Глава 6. Права и обязанности водителей и других лиц в особых случаях.",
        7: "Глава 7. Сигналы регулировщика и светофоров.",
        8: "Глава 8. Применение аварийной световой сигнализации, знака аварийной остановки, фонаря с мигающим красным светом.",
        9: "Глава 9. Маневрирование.",
        10: "Глава 10. Расположение транспортных средств на проезжей части дороги.",
        11: "Глава 11. Скорость движения транспортных средств.",
        12: "Глава 12. Обгон, встречный разъезд.",
        13: "Глава 13. Проезд перекрёстков.",
        14: "Глава 14. Пешеходные переходы, велосипедные переезды и остановочные пункты маршрутных транспортных средств.",
        15: "Глава 15. Преимущество маршрутных транспортных средств.",
        16: "Глава 16. Железнодорожные переезды.",
        17: "Глава 17. Движение по автомагистрали.",
        18: "Глава 18. Движение в жилой и пешеходной зонах, на прилегающей территории.",
        19: "Глава 19. Остановка и стоянка транспортных средств.",
        20: "Глава 20. Движение на велосипедах, средствах персональной мобильности и мопедах.",
        21: "Глава 21. Движение гужевых транспортных средств, всадников и прогон скота.",
        22: "Глава 22. Пользование внешними световыми приборами и звуковыми сигналами транспортных средств.",
        23: "Глава 23. Перевозка пассажиров.",
        24: "Глава 24. Перевозка грузов.",
        25: "Глава 25. Буксировка механических транспортных средств.",
        26: "Глава 26. Основные положения о допуске транспортных средств к участию в дорожном движении, их техническое состояние, оборудование.",
        27: "Глава 27. Обязанности должностных и иных лиц по обеспечению безопасности дорожного движения."
    ]
    
    private static let appendixTitles: [Int: String] = [
        1: "Приложение 1. Дорожные светофоры.",
        2: "Приложение 2. Дорожные знаки.",
        3: "Приложение 3. Дорожная разметка.",
        4: "Приложение 4. Перечень неисправностей транспортных средств и условий, при которых запрещается их участие в дорожном движении.",
        5: "Приложение 5. Опознавательные знаки транспортных средств."
    ]

    @StateObject private var navigationState = AppNavigationState()

    var body: some Scene {
        WindowGroup("TrafficMaster") {
            ContentView()
                .environmentObject(navigationState)
                .onAppear {
                    // Start import in background if needed
                    Task.detached(priority: .background) {
                        await importDataIfNeeded()
                    }
                }
        }
        .commands {
            TrafficMasterCommands(navigationState: navigationState)
        }

#if os(macOS)
        Settings {
            AppSettingsView()
        }
#endif
    }
    
    private func cleanOptionText(_ option: String) -> String {
        let pattern = #"^\s*\d+[\.\)\-\s/]+\s*"#
        let cleaned = option.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractLeadingNumber(from text: String) -> Int? {
        let digits = text.unicodeScalars
            .drop(while: { !CharacterSet.decimalDigits.contains($0) })
            .prefix(while: { CharacterSet.decimalDigits.contains($0) })
        guard !digits.isEmpty, let value = Int(String(String.UnicodeScalarView(digits))) else { return nil }
        return value
    }
    
    private func normalizedRuleSectionAndChapter(from parts: [String]) -> (section: String, chapter: String) {
        let defaultSection = "Главы Правил дорожного движения Республики Беларусь"
        let defaultChapter = parts.count >= 4 ? parts[3] : "Глава"
        
        guard parts.count >= 4 else {
            return (defaultSection, defaultChapter)
        }
        
        let rawChapter = parts[3]
        let rawPart = parts.count >= 5 ? parts[4] : nil
        
        if rawChapter.contains("Глава"), let number = extractLeadingNumber(from: rawChapter) {
            let base = Self.chapterTitles[number] ?? "Глава \(number)."
            if let rawPart, rawPart.contains("Часть") {
                return (defaultSection, "\(base) (\(rawPart))")
            }
            return (defaultSection, base)
        }
        
        if rawChapter.contains("Приложение"), let number = extractLeadingNumber(from: rawChapter) {
            let section = "Приложения к Правилам дорожного движения"
            let base = Self.appendixTitles[number] ?? "Приложение \(number)."
            if let rawPart, (rawPart.contains("Параграф") || rawPart.contains("Часть")) {
                return (section, "\(base) (\(rawPart))")
            }
            return (section, base)
        }
        
        return (defaultSection, defaultChapter)
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
                    let normalized = normalizedRuleSectionAndChapter(from: parts)
                    let section = normalized.section
                    let chapter = normalized.chapter

                    let cleanedText = importQ.question.replacingOccurrences(of: "\n", with: " ")
                    let key = "\(cleanedText)|\(section)|\(chapter)"
                    
                    let cleanedOptions = importQ.options.map { cleanOptionText($0.replacingOccurrences(of: "\n", with: " ")) }
                    let answerOptions = cleanedOptions.enumerated().map { idx, text in
                        AnswerOption(
                            text: text,
                            isCorrect: idx == importQ.correctIndex,
                            order: idx
                        )
                    }

                    var imageName: String?
                    if let img = importQ.image {
                        let filename = img.replacingOccurrences(of: "images/", with: "")
                        let nameWithoutExt = filename.components(separatedBy: ".").dropLast().joined(separator: ".")
                        imageName = nameWithoutExt.isEmpty ? filename : nameWithoutExt
                    }

                    if let existing = existingMap[key] {
                        // Update static content
                        existing.options = cleanedOptions
                        existing.answerOptions = answerOptions
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
                            answerOptions: answerOptions,
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
