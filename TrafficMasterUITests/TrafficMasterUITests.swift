import XCTest

final class TrafficMasterUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testFullMarathonFlow() throws {
        let app = XCUIApplication()
        // Reset UserDefaults for a clean state in UI tests
        app.launchArguments.append("-resetData")
        app.launch()

        // 1. Handle Login (if presented)
        let nameTextField = app.textFields["Имя"]
        if nameTextField.waitForExistence(timeout: 5) {
            nameTextField.tap()
            nameTextField.typeText("TestUser")
            
            let startButton = app.buttons["Начать обучение"]
            XCTAssertTrue(startButton.waitForExistence(timeout: 2))
            startButton.tap()
        }
        
        // Wait for Database to load (it might take a few seconds)
        let homeTab = app.tabBars.buttons["Главная"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 15), "Главная вкладка не появилась")
        
        // 2. Start Marathon Mode
        let marathonButton = app.buttons.containing(.staticText, identifier: "Марафон режим").firstMatch
        XCTAssertTrue(marathonButton.waitForExistence(timeout: 5), "Кнопка марафона не найдена")
        marathonButton.tap()
        
        // 3. Interact with the Question View
        // Wait for the first option to appear
        let firstOption = app.scrollViews.buttons.firstMatch
        XCTAssertTrue(firstOption.waitForExistence(timeout: 10), "Варианты ответа не загрузились")
        
        // Tap the first option
        firstOption.tap()
        
        // Wait for action buttons to appear
        let nextButton = app.buttons["Дальше"]
        let guessedButton = app.buttons["Ответил наугад 🤔"]
        
        XCTAssertTrue(nextButton.waitForExistence(timeout: 2) || guessedButton.waitForExistence(timeout: 2), "Кнопки действий не появились после выбора ответа")
        
        if nextButton.exists {
            nextButton.tap()
        } else if guessedButton.exists {
            guessedButton.tap()
        }
        
        // Verify we moved to the next question (the options should reload)
        XCTAssertTrue(firstOption.waitForExistence(timeout: 5), "Следующий вопрос не загрузился")
        
        // Exit Marathon
        app.buttons["Назад"].tap()
        app.alerts["Вы действительно хотите выйти?"].buttons["Выйти"].tap()
        
        XCTAssertTrue(marathonButton.waitForExistence(timeout: 5), "Не вернулись на главный экран")
    }
    
    @MainActor
    func testNavigationAndTabs() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Ensure we are logged in or bypass login
        let nameTextField = app.textFields["Имя"]
        if nameTextField.waitForExistence(timeout: 3) {
            nameTextField.tap()
            nameTextField.typeText("TestUser")
            app.buttons["Начать обучение"].tap()
        }
        
        let tabBarsQuery = app.tabBars
        let homeTab = tabBarsQuery.buttons["Главная"]
        
        if homeTab.waitForExistence(timeout: 15) {
            // Переход на Прогресс
            let statsTab = tabBarsQuery.buttons["Прогресс"]
            if statsTab.exists {
                statsTab.tap()
                XCTAssertTrue(app.navigationBars["Прогресс"].waitForExistence(timeout: 5))
            }
            
            // Переход на Настройки
            let profileTab = tabBarsQuery.buttons["Профиль"]
            if profileTab.exists {
                profileTab.tap()
                XCTAssertTrue(app.navigationBars["Профиль"].waitForExistence(timeout: 5))
            }
        }
    }
    
    @MainActor
    func testProfileEditing() throws {
        let app = XCUIApplication()
        app.launch()
        
        let nameTextField = app.textFields["Имя"]
        if nameTextField.waitForExistence(timeout: 3) {
            nameTextField.tap()
            nameTextField.typeText("UITest")
            app.buttons["Начать обучение"].tap()
        }
        
        let profileTab = app.tabBars.buttons["Профиль"]
        if profileTab.waitForExistence(timeout: 15) {
            profileTab.tap()
            
            let editButton = app.buttons["Редактировать профиль"]
            if editButton.waitForExistence(timeout: 5) {
                editButton.tap()
                
                let editNameField = app.textFields["Имя"]
                if editNameField.waitForExistence(timeout: 2) {
                    editNameField.tap()
                    editNameField.typeText(" Updated")
                    app.buttons["Сохранить"].tap()
                    
                    // Verify the name updated on the profile screen
                    XCTAssertTrue(app.staticTexts["UITest Updated"].waitForExistence(timeout: 5))
                }
            }
        }
    }
}
