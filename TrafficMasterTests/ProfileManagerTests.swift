@testable import TrafficMaster
import Foundation
import XCTest

final class ProfileManagerTests: XCTestCase {
    private var manager: ProfileManager!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ProfileManagerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        manager = ProfileManager(defaults: defaults)
    }

    override func tearDown() {
        manager = nil
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertFalse(manager.isLoggedIn)
    }

    func testLogin() {
        manager.isLoggedIn = true
        XCTAssertTrue(defaults.bool(forKey: "isLoggedIn"))
    }

    func testProfileUpdate() {
        manager.username = "test_user"
        XCTAssertEqual(defaults.string(forKey: "username"), "test_user")
    }
}
