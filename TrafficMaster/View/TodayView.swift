import SwiftUI

struct TodayView: View {
    @StateObject private var viewModel = QuestionViewModel()
    @State private var showSession = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SoloUse FSRS")
                        .font(.title.bold())
                    Text("Локальная подготовка к экзамену ГАИ РБ")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 10) {
                    statRow("Карточек на сегодня", value: "\(viewModel.totalInSession)")
                    statRow("Пройдено в сессии", value: "\(viewModel.completedInSession)")
                    statRow("Новые/день", value: "\(viewModel.settings.newCardsPerDay)")
                    statRow("Макс. повторов/день", value: "\(viewModel.settings.maxReviewsPerDay)")
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button("Начать сессию") {
                    showSession = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.totalInSession == 0)

                if let message = viewModel.generatedExplanation, viewModel.totalInSession == 0 {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Подготовка")
            .onAppear {
                viewModel.refreshSettings()
                viewModel.loadSession()
            }
            .sheet(isPresented: $showSession) {
                QuestionSessionView(viewModel: viewModel)
            }
        }
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    TodayView()
}
