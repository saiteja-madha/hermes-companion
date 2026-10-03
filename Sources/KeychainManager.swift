import Foundation
import Security

/// Manages connection configs and API keys in iOS Keychain.
///
/// Single-connection (legacy): `active_config` key holds the active ConnectionConfig.
/// Multi-connection: `all_configs` key holds [ConnectionConfig]; the active one
/// is identified by its stable `endpointID` match against `active_config`. The single
/// key is kept in sync so existing code paths that call `loadActive()` /
/// `deleteActive()` still work.
final class KeychainManager: Sendable {
    static let shared = KeychainManager()
    private init() {}

    private let service = AppConfig.keychainService

    // MARK: - Single-config (legacy, still used for "active" pointer)

    func save(_ config: ConnectionConfig) throws {
        let data = try JSONEncoder().encode(config)
        try save(key: "active_config", data: data)
    }

    func loadActive() -> ConnectionConfig? {
        guard let data = load(key: "active_config") else { return nil }
        guard let config = try? JSONDecoder().decode(ConnectionConfig.self, from: data) else { return nil }
        // Persist the generated endpoint ID when decoding a pre-ID record.
        if !Self.containsEndpointID(data) { try? save(config) }
        return config
    }

    func deleteActive() {
        delete(key: "active_config")
    }

    // MARK: - Multi-config

    /// All saved connection configs, in display order (most-recently-used first).
    func loadAll() -> [ConnectionConfig] {
        guard let data = load(key: "all_configs") else { return [] }
        if let arr = try? JSONDecoder().decode([ConnectionConfig].self, from: data) {
            // One-time, in-place migration of legacy records. API keys never
            // leave the Keychain; only the encoded record gains endpointID.
            if !Self.allRecordsContainEndpointID(data) { try? saveAll(arr) }
            return arr
        }
        return []
    }

    /// Replace the full list. Use `addOrUpdate` / `remove` for normal flows.
    func saveAll(_ configs: [ConnectionConfig]) throws {
        let data = try JSONEncoder().encode(configs)
        try save(key: "all_configs", data: data)
    }

    /// Insert or update a config (stable ID first, normalized URL for legacy callers).
    /// Returns the updated list.
    @discardableResult
    func addOrUpdate(_ config: ConnectionConfig) throws -> [ConnectionConfig] {
        var all = loadAll()
        var stored = config
        if let idx = all.firstIndex(where: {
            $0.endpointID == config.endpointID || $0.normalizedBaseURL == config.normalizedBaseURL
        }) {
            // A legacy edit form may construct a fresh UUID for the same URL.
            // Preserve the already persisted identity in that case.
            stored.endpointID = all[idx].endpointID
            all[idx] = stored
        } else {
            all.insert(stored, at: 0)
        }
        try saveAll(all)
        return all
    }

    /// Remove a config by stable endpoint ID. Also clears the active pointer if needed.
    @discardableResult
    func remove(endpointID: UUID) throws -> [ConnectionConfig] {
        var all = loadAll()
        all.removeAll { $0.endpointID == endpointID }
        try saveAll(all)
        if let active = loadActive(), active.endpointID == endpointID {
            deleteActive()
        }
        return all
    }

    /// Mark a config as active by stable endpoint ID. Persists it to `active_config` so
    /// legacy `loadActive()` callers (AppStore init) see the right one.
    func setActive(endpointID: UUID) throws {
        let all = loadAll()
        guard let config = all.first(where: { $0.endpointID == endpointID }) else { return }
        try save(config)
    }

    private static func containsEndpointID(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return object["endpointID"] is String
    }

    private static func allRecordsContainEndpointID(_ data: Data) -> Bool {
        guard let objects = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return false }
        return objects.allSatisfy { $0["endpointID"] is String }
    }

    // MARK: - Private Keychain Operations

    private func save(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        // Delete existing
        SecItemDelete(query as CFDictionary)

        // Add new
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    private func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return data
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum KeychainError: Error {
    case saveFailed(status: OSStatus)
}
