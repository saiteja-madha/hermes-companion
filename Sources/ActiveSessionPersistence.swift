import Foundation

struct ActiveSessionPersistence {
    private let defaults: UserDefaults
    private let keyPrefix = "active_session."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(sessionID: String, for endpointID: UUID) {
        defaults.set(sessionID, forKey: key(for: endpointID))
    }

    /// Load endpoint-scoped state and migrate the former URL-scoped key once.
    func load(for endpointID: UUID, legacyBaseURL: String? = nil) -> String? {
        if let current = defaults.string(forKey: key(for: endpointID)) { return current }
        guard let legacyBaseURL,
              let legacy = defaults.string(forKey: legacyKey(for: legacyBaseURL)) else { return nil }
        save(sessionID: legacy, for: endpointID)
        defaults.removeObject(forKey: legacyKey(for: legacyBaseURL))
        return legacy
    }

    func clear(for endpointID: UUID, legacyBaseURL: String? = nil) {
        defaults.removeObject(forKey: key(for: endpointID))
        if let legacyBaseURL { defaults.removeObject(forKey: legacyKey(for: legacyBaseURL)) }
    }

    private func key(for endpointID: UUID) -> String {
        keyPrefix + endpointID.uuidString.lowercased()
    }

    private func legacyKey(for baseURL: String) -> String {
        keyPrefix + baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
