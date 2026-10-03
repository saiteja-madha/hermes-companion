import Foundation
import AppIntents

enum VoiceEndpointingPolicy {
    /// Natural conversation includes short thinking pauses. Anything below a
    /// second aggressively fragments speech into separate turns.
    /// 1.5s is the floor of the natural-pause band (test asserts >= 1.5).
    static let silenceTimeout: TimeInterval = 1.5
}

/// Immutable identity captured when a voice conversation starts.
///
/// Voice turns must stay attached to this endpoint even if another part of the
/// app changes the globally selected connection. This prevents a delayed
/// transcription from being delivered to a different Hermes installation.
struct VoiceEndpointBinding: Equatable, Sendable {
    let endpointID: UUID
    let baseURL: String
    let label: String

    init(config: ConnectionConfig) {
        endpointID = config.endpointID
        baseURL = config.normalizedBaseURL
        label = config.label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayName: String {
        if !label.isEmpty { return label }
        return URL(string: baseURL)?.host ?? baseURL
    }

    func matches(_ config: ConnectionConfig?) -> Bool {
        config?.endpointID == endpointID && config?.normalizedBaseURL == baseURL
    }
}

enum VoiceLaunchEndpointResolver {
    /// Resolve an intent without availability-based fallback. An explicit but
    /// missing endpoint returns nil instead of silently selecting another server.
    static func resolve(
        requestedID: UUID?,
        preferredID: UUID?,
        current: ConnectionConfig?,
        saved: [ConnectionConfig]
    ) -> ConnectionConfig? {
        if let requestedID {
            return saved.first { $0.endpointID == requestedID }
        }
        if let preferredID {
            return saved.first { $0.endpointID == preferredID }
        }
        return current
    }
}

enum WakePhraseParser {
    static func containsWakePhrase(_ transcription: String) -> Bool {
        let words = transcription
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        guard words.count >= 2 else { return false }
        return zip(words, words.dropFirst()).contains { first, second in
            first == "hey" && second == "hermes"
        }
    }
}

// MARK: - Siri / App Shortcuts

struct HermesEndpointEntity: AppEntity, Identifiable {
    let id: String
    let name: String

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Hermes Server")
    static var defaultQuery = HermesEndpointEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct HermesEndpointEntityQuery: EntityQuery {
    func entities(for identifiers: [HermesEndpointEntity.ID]) async throws -> [HermesEndpointEntity] {
        let wanted = Set(identifiers)
        return Self.current().filter { wanted.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HermesEndpointEntity] {
        Self.current()
    }

    private static func current() -> [HermesEndpointEntity] {
        VoiceActivationControlConstants.cachedEndpoints().map {
            HermesEndpointEntity(id: $0.id.uuidString, name: $0.name)
        }
    }
}

struct StartHermesVoiceIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Hermes Voice"
    static var description = IntentDescription("Start a voice conversation with the preferred Hermes server.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        VoiceActivationControlConstants.requestVoiceLaunch(
            endpointID: VoiceActivationControlConstants.preferredEndpointID()
        )
        NotificationCenter.default.post(name: .openVoiceMode, object: nil)
        return .result()
    }
}

struct StartHermesVoiceOnEndpointIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Hermes Voice on Server"
    static var description = IntentDescription("Start a voice conversation with a specific Hermes server.")
    static var openAppWhenRun = true

    @Parameter(title: "Server")
    var endpoint: HermesEndpointEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Start Hermes voice with \(\.$endpoint)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        VoiceActivationControlConstants.requestVoiceLaunch(
            endpointID: UUID(uuidString: endpoint.id)
        )
        NotificationCenter.default.post(name: .openVoiceMode, object: nil)
        return .result()
    }
}

struct HermesVoiceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartHermesVoiceIntent(),
            phrases: [
                "Start \(.applicationName)",
                "Talk to \(.applicationName)",
                "Start voice mode in \(.applicationName)"
            ],
            shortTitle: "Start Hermes",
            systemImageName: "waveform.badge.mic"
        )
        AppShortcut(
            intent: StartHermesVoiceOnEndpointIntent(),
            phrases: [
                "Start \(\.$endpoint) in \(.applicationName)",
                "Start \(.applicationName) on \(\.$endpoint)",
                "Talk to \(\.$endpoint) with \(.applicationName)"
            ],
            shortTitle: "Start Hermes Server",
            systemImageName: "server.rack"
        )
    }
}
