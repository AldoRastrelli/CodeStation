import XCTest
@testable import CodeStation

final class NotificationDelegateTests: XCTestCase {

    func testOnNotificationTappedCallbackCanBeSet() {
        let delegate = NotificationDelegate()
        var receivedEnvID: UUID?
        var receivedSessionID: UUID?

        delegate.onNotificationTapped = { envID, sessionID in
            receivedEnvID = envID
            receivedSessionID = sessionID
        }

        let envID = UUID()
        let sessionID = UUID()
        delegate.onNotificationTapped?(envID, sessionID)

        XCTAssertEqual(receivedEnvID, envID)
        XCTAssertEqual(receivedSessionID, sessionID)
    }

    func testOnNotificationTappedDefaultIsNil() {
        let delegate = NotificationDelegate()
        XCTAssertNil(delegate.onNotificationTapped)
    }
}
