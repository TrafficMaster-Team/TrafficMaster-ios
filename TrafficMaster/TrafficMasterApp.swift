//
//  TrafficMasterApp.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import SwiftUI
import SwiftData

@main
struct TrafficMasterApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Question.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Проверка и заполнение базы данных (seed data)
            let context = ModelContext(container)
            let questionDescriptor = FetchDescriptor<Question>()
            
            let existingQuestions = try context.fetch(questionDescriptor)
            
            // Проверяем версию базы данных через UserDefaults
            let currentDBVersion = 2
            let savedDBVersion = UserDefaults.standard.integer(forKey: "db_version")
            
            if savedDBVersion < currentDBVersion {
                // Полная очистка старой базы
                for q in existingQuestions {
                    context.delete(q)
                }
                
                // Загрузка новых вопросов
                for question in MockData.questions {
                    context.insert(question)
                }
                try context.save()
                
                // Обновляем версию
                UserDefaults.standard.set(currentDBVersion, forKey: "db_version")
            }
            
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
