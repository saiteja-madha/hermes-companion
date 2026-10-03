import Foundation
import WidgetKit

// MARK: - Shared Defaults (App Group)

/// Shared UserDefaults via App Group so the main app and Control Widget
/// extension can read/write the same settings.
enum SharedDefaults {
    static let suiteName = "group.com.chibitek.hermescompanion"
    static let shared: UserDefaults = {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        migrateWakeListeningConsent(in: defaults)
        return defaults
    }()

    static func migrateWakeListeningConsent(in defaults: UserDefaults) {
        // Previous releases enabled recording by default. Require a fresh opt-in.
        guard !defaults.bool(forKey: "wake_listening_explicit_consent_v1") else { return }
        defaults.set(false, forKey: "hey_hermes_enabled")
        defaults.set(true, forKey: "wake_listening_explicit_consent_v1")
    }
}

enum VoiceActivationControlConstants {
    static let kind = "com.chibitek.hermescompanion.voice-activation"
    static let preferredEndpointIDKey = "preferred_voice_endpoint_id"
    static let endpointCatalogKey = "voice_endpoint_catalog_v1"
    static let pendingEndpointIDKey = "pending_voice_endpoint_id"
    static let openVoicePageKey = "open_voice_page"

    static func preferredEndpointID(in defaults: UserDefaults = SharedDefaults.shared) -> UUID? {
        defaults.string(forKey: preferredEndpointIDKey).flatMap(UUID.init(uuidString:))
    }

    static func setPreferredEndpointID(_ id: UUID?, in defaults: UserDefaults = SharedDefaults.shared) {
        defaults.set(id?.uuidString, forKey: preferredEndpointIDKey)
    }

    static func cacheEndpoints(_ endpoints: [VoiceEndpointDescriptor], in defaults: UserDefaults = SharedDefaults.shared) {
        defaults.set(try? JSONEncoder().encode(endpoints), forKey: endpointCatalogKey)
    }

    static func cachedEndpoints(in defaults: UserDefaults = SharedDefaults.shared) -> [VoiceEndpointDescriptor] {
        guard let data = defaults.data(forKey: endpointCatalogKey) else { return [] }
        return (try? JSONDecoder().decode([VoiceEndpointDescriptor].self, from: data)) ?? []
    }

    static func requestVoiceLaunch(endpointID: UUID?, in defaults: UserDefaults = SharedDefaults.shared) {
        defaults.set(endpointID?.uuidString, forKey: pendingEndpointIDKey)
        defaults.set(true, forKey: openVoicePageKey)
    }

    static func pendingEndpointID(in defaults: UserDefaults = SharedDefaults.shared) -> UUID? {
        defaults.string(forKey: pendingEndpointIDKey).flatMap(UUID.init(uuidString:))
    }

    static func clearPendingVoiceLaunch(in defaults: UserDefaults = SharedDefaults.shared) {
        defaults.removeObject(forKey: pendingEndpointIDKey)
        defaults.set(false, forKey: openVoicePageKey)
    }
}

/// Deliberately secret-free endpoint metadata shared with App Intents and widgets.
struct VoiceEndpointDescriptor: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
}

extension Notification.Name {
    static let openVoiceMode = Notification.Name("com.chibitek.hermescompanion.openVoiceMode")
}
