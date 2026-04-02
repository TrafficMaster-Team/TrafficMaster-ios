@testable import TrafficMaster
import XCTest

final class ProfileManagerTests: XCTestCase {
    var manager: ProfileManager!
    
    override func setUp() {
        super.setUp()
        manager = ProfileManager.shared
        // Reset login state for testing if possible
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
    }
    
    func testInitialState() {
        XCTAssertFalse(manager.isLoggedIn)
    }
    
    func testLogin() {
        manager.isLoggedIn = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "isLoggedIn"))
    }
    
    func testProfileUpdate() {
        manager.userName = "Test User"
        XCTAssertEqual(UserDefaults.standard.string(forKey: "userName"), "Test User")
    }
}
