import Foundation

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
    let baseURL: String
    let label: String

    init(config: ConnectionConfig) {
        baseURL = config.normalizedBaseURL
        label = config.label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayName: String {
        if !label.isEmpty { return label }
        return URL(string: baseURL)?.host ?? baseURL
    }

    func matches(_ config: ConnectionConfig?) -> Bool {
        config?.normalizedBaseURL == baseURL
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
