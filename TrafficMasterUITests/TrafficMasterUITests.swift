import XCTest

final class TrafficMasterUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {}

    @MainActor
    private func completeOnboarding(in app: XCUIApplication) {
        let demoButton = app.buttons["Заполнить демо-данные"]
        XCTAssertTrue(demoButton.waitForExistence(timeout: 5), "Форма регистрации не появилась")
        demoButton.tap()

        let startButton = app.buttons["Начать обучение"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 2), "Кнопка начала обучения не появилась")
        XCTAssertTrue(startButton.isEnabled, "Кнопка начала обучения недоступна после заполнения формы")
        startButton.tap()

        XCTAssertTrue(
            app.tabBars.buttons["Главная"].waitForExistence(timeout: 15),
            "Главная вкладка не появилась"
        )
    }

    @MainActor
    func testFullStudyFlow() {
        let app = XCUIApplication()
        // Reset UserDefaults for a clean state in UI tests
        app.launchArguments.append("-resetData")
        app.launch()

        // 1. Complete onboarding with local demo credentials.
        completeOnboarding(in: app)

        // 2. Start daily study mode
        let studyButton = app.buttons["dailyStudyButton"]
        XCTAssertTrue(studyButton.waitForExistence(timeout: 5), "Кнопка обучения не найдена")
        studyButton.tap()

        // 3. Interact with the Question View
        // Wait for the first option to appear
        let firstOption = app.scrollViews.buttons.firstMatch
        XCTAssertTrue(firstOption.waitForExistence(timeout: 10), "Варианты ответа не загрузились")

        // Tap the first option
        firstOption.tap()

        // Wait for action buttons to appear
        let nextButton = app.buttons["Дальше"]
        let guessedButton = app.buttons["Ответил наугад 🤔"]

        XCTAssertTrue(
            nextButton.waitForExistence(timeout: 2) || guessedButton.waitForExistence(timeout: 2),
            "Кнопки действий не появились после выбора ответа"
        )

        if nextButton.exists {
            nextButton.tap()
        } else if guessedButton.exists {
            guessedButton.tap()
        }

        // Verify we moved to the next question (the options should reload)
        XCTAssertTrue(firstOption.waitForExistence(timeout: 5), "Следующий вопрос не загрузился")

        // Exit Study
        app.buttons["studyBackButton"].tap()
        app.alerts["Вы действительно хотите выйти?"].buttons["Выйти"].tap()

        XCTAssertTrue(studyButton.waitForExistence(timeout: 5), "Не вернулись на главный экран")
    }

    @MainActor
    func testNavigationAndTabs() {
        let app = XCUIApplication()
        app.launchArguments.append("-resetData")
        app.launch()
        completeOnboarding(in: app)

        let tabBar = app.tabBars

        let statsTab = tabBar.buttons["Статистика"]
        XCTAssertTrue(statsTab.waitForExistence(timeout: 5), "Вкладка Статистика не найдена")
        statsTab.tap()
        XCTAssertTrue(app.navigationBars["Прогресс"].waitForExistence(timeout: 5))

        let profileTab = tabBar.buttons["Профиль"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5), "Вкладка Профиль не найдена")
        profileTab.tap()
        XCTAssertTrue(app.navigationBars["Профиль"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testProfileEditing() {
        let app = XCUIApplication()
        app.launchArguments.append("-resetData")
        app.launch()
        completeOnboarding(in: app)

        let profileTab = app.tabBars.buttons["Профиль"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5), "Вкладка Профиль не найдена")
        profileTab.tap()

        let editButton = app.buttons["editProfileButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Редактирование профиля недоступно")
        editButton.tap()

        let editNameField = app.textFields["Имя"]
        XCTAssertTrue(editNameField.waitForExistence(timeout: 5), "Поле имени не найдено")
        editNameField.tap()
        editNameField.typeText(" Updated ")

        let updatedNamePredicate = NSPredicate(format: "value == %@", "Демо Updated ")
        expectation(for: updatedNamePredicate, evaluatedWith: editNameField)
        waitForExpectations(timeout: 2)
        app.textFields["Фамилия"].tap()

        let saveButton = app.buttons["Сохранить"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2), "Кнопка сохранения не найдена")
        saveButton.tap()

        let reopenedEditButton = app.buttons["editProfileButton"]
        XCTAssertTrue(reopenedEditButton.waitForExistence(timeout: 5), "Профиль не сохранился")
        reopenedEditButton.tap()

        let savedFirstNameField = app.textFields["Имя"]
        let savedLastNameField = app.textFields["Фамилия"]
        XCTAssertTrue(savedFirstNameField.waitForExistence(timeout: 5), "Сохранённое имя недоступно")
        XCTAssertEqual(savedFirstNameField.value as? String, "Демо Updated")
        XCTAssertEqual(savedLastNameField.value as? String, "Пользователь")
    }
}
