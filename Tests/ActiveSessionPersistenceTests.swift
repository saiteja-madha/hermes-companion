import XCTest
@testable import HermesCompanion

final class ActiveSessionPersistenceTests: XCTestCase {
    func testRestoresSavedSessionOnlyForMatchingConnection() {
        let defaults = isolatedDefaults()
        let persistence = ActiveSessionPersistence(defaults: defaults)
        let first = UUID()
        let second = UUID()

        persistence.save(sessionID: "session-42", for: first)

        XCTAssertEqual(persistence.load(for: first), "session-42")
        XCTAssertNil(persistence.load(for: second))
    }

    func testClearRemovesSavedSessionForConnection() {
        let defaults = isolatedDefaults()
        let persistence = ActiveSessionPersistence(defaults: defaults)
        let endpointID = UUID()
        persistence.save(sessionID: "session-42", for: endpointID)

        persistence.clear(for: endpointID)

        XCTAssertNil(persistence.load(for: endpointID))
    }

    func testMigratesLegacyURLScopedSessionToStableEndpointID() {
        let defaults = isolatedDefaults()
        let persistence = ActiveSessionPersistence(defaults: defaults)
        let endpointID = UUID()
        let baseURL = "http://hermes-one:8642/"
        defaults.set("legacy-session", forKey: "active_session.http://hermes-one:8642")

        XCTAssertEqual(
            persistence.load(for: endpointID, legacyBaseURL: baseURL),
            "legacy-session"
        )
        XCTAssertEqual(persistence.load(for: endpointID), "legacy-session")
        XCTAssertNil(defaults.string(forKey: "active_session.http://hermes-one:8642"))
    }

    private func isolatedDefaults() -> UserDefaults {
        let suite = "ActiveSessionPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
