//
//  ExamModeSettingsView.swift
//  TrafficMaster
//
//  Presentation Layer - Exam Mode Settings UI
//

import SwiftUI

/// Настройки предэкзаменационного режима
struct ExamModeSettingsView: View {
    @State private var isEnabled: Bool = false
    @State private var examDate: Date? = Date().addingTimeInterval(14 * 24 * 60 * 60)
    @State private var dailyLimit: Int = 400
    @State private var filterByWeakTopics: Bool = false
    @State private var readinessStats: ExamReadinessStats?
    
    @Environment(\.dismiss) private var dismiss
    
    private let storage = ExamModeStorage()
    private let filterService = ExamFilterService()
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Включить предэкзаменационный режим", isOn: $isEnabled)
                    
                    if isEnabled {
                        DatePicker(
                            "Дата экзамена",
                            selection: Binding(
                                get: { examDate ?? Date() },
                                set: { examDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                        
                        Stepper("Карточек в день: \(dailyLimit)", value: $dailyLimit, in: 100...1000, step: 50)
                        
                        Toggle("Только слабые темы", isOn: $filterByWeakTopics)
                        
                        if let days = daysUntilExam {
                            HStack {
                                Image(systemName: "calendar")
                                Text("До экзамена: \(days) дн.")
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Режим подготовки")
                } footer: {
                    if isEnabled {
                        Text("В этом режиме FSRS приостанавливается. Все билеты будут показываться повторно для закрепления краткосрочной памяти.")
                    }
                }
                
                if isEnabled, let stats = readinessStats {
                    Section("Ваша готовность") {
                        readinessView(stats: stats)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("Как это работает")
                                .fontWeight(.semibold)
                        }
                        
                        Text("• Показывает ВСЕ билеты (или только слабые темы)")
                        Text("• FSRS НЕ обновляет интервалы (глобальный график не ломается)")
                        Text("• При ошибке билет возвращается в очередь через 15-40 позиций")
                        Text("• Рекомендуется за 2-3 недели до экзамена")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Section {
                    Button(action: applyPresetTwoWeeks) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                            Text("Пресет: 2 недели до экзамена")
                        }
                    }
                    
                    Button(action: applyPresetThreeDays) {
                        HStack {
                            Image(systemName: "calendar.badge.exclamationmark")
                            Text("Пресет: 3 дня до экзамена")
                        }
                    }
                } header: {
                    Text("Быстрые настройки")
                }
            }
            .navigationTitle("Экзаменационный режим")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveConfiguration()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadConfiguration()
            loadStats()
        }
    }
    
    // MARK: - Private Methods
    
    private func readinessView(stats: ExamReadinessStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(stats.readinessMessage)
                .font(.headline)
                .foregroundColor(stats.predictedSuccessRate > 0.85 ? .green : .orange)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Шанс сдачи")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(stats.predictedSuccessRate * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Выучено")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(stats.masteryPercentage))%")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
            
            ProgressView(value: stats.predictedSuccessRate)
                .tint(stats.predictedSuccessRate > 0.85 ? .green : .orange)
        }
        .padding(.vertical, 8)
    }
    
    private var daysUntilExam: Int? {
        guard let examDate = examDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: examDate).day ?? 0
    }
    
    private func loadConfiguration() {
        let config = storage.loadConfiguration()
        isEnabled = config.isEnabled
        examDate = config.examDate
        dailyLimit = config.dailyCardLimit
        filterByWeakTopics = config.filterByWeakTopics
    }
    
    private func loadStats() {
        readinessStats = try? filterService.getExamReadinessStats()
    }
    
    private func saveConfiguration() {
        let config = ExamModeConfiguration(
            isEnabled: isEnabled,
            examDate: isEnabled ? examDate : nil,
            dailyCardLimit: dailyLimit,
            filterByWeakTopics: filterByWeakTopics,
            minErrorsForWeakTopic: 3,
            suspendFSRS: isEnabled
        )
        storage.saveConfiguration(config)
    }
    
    private func applyPresetTwoWeeks() {
        isEnabled = true
        examDate = Date().addingTimeInterval(14 * 24 * 60 * 60)
        dailyLimit = 400
        filterByWeakTopics = false
    }
    
    private func applyPresetThreeDays() {
        isEnabled = true
        examDate = Date().addingTimeInterval(3 * 24 * 60 * 60)
        dailyLimit = 600
        filterByWeakTopics = true
    }
}

// MARK: - Preview

#Preview {
    ExamModeSettingsView()
}
