import XCTest

final class TrafficMasterUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testNavigationAndTabs() throws {
        let app = XCUIApplication()
        app.launch()
        
        let tabBarsQuery = app.tabBars
        let homeTab = tabBarsQuery.buttons["Главная"]
        
        if homeTab.waitForExistence(timeout: 10) {
            // Переход на Прогресс
            let statsTab = tabBarsQuery.buttons["Прогресс"]
            if statsTab.exists {
                statsTab.tap()
                XCTAssertTrue(app.staticTexts["Прогресс"].waitForExistence(timeout: 2))
            }
            
            // Переход на Настройки
            let profileTab = tabBarsQuery.buttons["Настройки"]
            if profileTab.exists {
                profileTab.tap()
                XCTAssertTrue(app.staticTexts["Профиль"].waitForExistence(timeout: 2))
            }
        }
    }
    
    @MainActor
    func testVisualCounters() throws {
        let app = XCUIApplication()
        app.launch()
        
        let homeTab = app.tabBars.buttons["Главная"]
        if homeTab.waitForExistence(timeout: 10) {
            // Проверка, что на главном экране есть кнопка марафона
            XCTAssertTrue(app.staticTexts["Марафон режим"].exists)
        }
    }
}
