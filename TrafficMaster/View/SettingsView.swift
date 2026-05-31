import SwiftUI

struct SettingsView: View {
    @State private var settings: StudySettings = .default
    @State private var apiKey: String = ""
    @State private var exportPackPath: String = ""
    @State private var showFolderPicker = false
    @State private var saveMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("FSRS") {
                    Stepper("Новых карточек в день: \(settings.newCardsPerDay)", value: $settings.newCardsPerDay, in: 5...200, step: 1)
                    Stepper("Макс. повторов в день: \(settings.maxReviewsPerDay)", value: $settings.maxReviewsPerDay, in: 20...1000, step: 10)
                    Toggle("Показывать кнопку Easy", isOn: $settings.showEasyButton)
                }

                Section("AI Разбор Ошибок") {
                    Toggle("Включить AI объяснения", isOn: $settings.aiExplanationsEnabled)
                    TextField("OpenRouter model", text: $settings.openRouterModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    SecureField("OpenRouter API key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }

                Section("База Вопросов") {
                    TextField("Путь к export_all_questions", text: $exportPackPath)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    Button("Выбрать папку в Files") {
                        showFolderPicker = true
                    }
                    Button("Применить путь и переимпортировать") {
                        DataPackManager.configuredPath = exportPackPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? nil
                            : exportPackPath.trimmingCharacters(in: .whitespacesAndNewlines)
                        do {
                            try DatabaseService.shared.importBundledQuestionsIfNeeded()
                            saveMessage = "Переимпорт выполнен"
                        } catch {
                            saveMessage = "Ошибка импорта: \\(error.localizedDescription)"
                        }
                    }
                }

                Section {
                    Button("Сохранить настройки") { save() }
                    Button("Очистить API key", role: .destructive) {
                        KeychainService.clearOpenRouterKey()
                        apiKey = ""
                        saveMessage = "API key удалён"
                    }
                }

                if let saveMessage {
                    Section {
                        Text(saveMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Настройки")
            .onAppear(perform: load)
            .sheet(isPresented: $showFolderPicker) {
                ExportFolderPicker { url in
                    do {
                        let local = try DataPackManager.importPickedExportFolder(url)
                        exportPackPath = local.path
                        try DatabaseService.shared.importBundledQuestionsIfNeeded()
                        saveMessage = "Папка импортирована и база обновлена"
                    } catch {
                        saveMessage = "Ошибка импорта папки: \\(error.localizedDescription)"
                    }
                    showFolderPicker = false
                }
            }
        }
    }

    private func load() {
        settings = (try? DatabaseService.shared.loadSettings()) ?? .default
        apiKey = KeychainService.loadOpenRouterKey() ?? ""
        exportPackPath = DataPackManager.configuredPath ?? DataPackManager.defaultMacPath()
    }

    private func save() {
        do {
            try DatabaseService.shared.saveSettings(settings)
            if !apiKey.isEmpty {
                try KeychainService.saveOpenRouterKey(apiKey)
            }
            saveMessage = "Сохранено"
        } catch {
            saveMessage = "Ошибка сохранения: \(error.localizedDescription)"
        }
    }
}

#Preview {
    SettingsView()
}
