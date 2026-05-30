import SwiftUI

struct AppSettingsView: View {
    @AppStorage("daily_new_cards_limit") private var dailyNewCardsLimit = 34
    @AppStorage("enable_study_notifications") private var enableStudyNotifications = true

    var body: some View {
        Form {
            Stepper(value: $dailyNewCardsLimit, in: 10...100, step: 2) {
                Text("Новых карточек в день: \(dailyNewCardsLimit)")
            }

            Toggle("Разрешить учебные уведомления", isOn: $enableStudyNotifications)
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(minWidth: 420, idealWidth: 480, maxWidth: 560)
    }
}

#Preview {
    AppSettingsView()
}
