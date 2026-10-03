import ActivityKit
import Foundation

/// Credential-free state shared by the app and its widget extension.
///
/// Never add endpoint URLs, API keys, prompts, transcripts, response text, tool
/// arguments, file paths, or command output here. ActivityKit may render this
/// state while the phone is locked and may archive it outside the app process.
struct HermesVoiceActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        var phase: HermesVoiceActivityPhase
        var toolCount: Int
        var isMuted: Bool
        var updatedAt: Date

        static func ended(at date: Date = Date()) -> Self {
            Self(phase: .ended, toolCount: 0, isMuted: false, updatedAt: date)
        }
    }

    let conversationID: UUID
    let endpointID: UUID
    let endpointName: String
    let startedAt: Date
}

enum HermesVoiceActivityPhase: String, Codable, Hashable, Sendable {
    case listening
    case thinking
    case usingTools
    case speaking
    case paused
    case reconnecting
    case failed
    case ended
}

/// A compact, Equatable projection of app state used to coalesce ActivityKit
/// updates and to make state precedence independently testable.
struct HermesVoiceActivitySignal: Equatable, Sendable {
    let phase: HermesVoiceActivityPhase
    let toolCount: Int
    let isMuted: Bool
}

enum HermesVoiceActivityStateResolver {
    static func resolve(
        isConversing: Bool,
        isListening: Bool,
        isSpeaking: Bool,
        isThinking: Bool,
        isMuted: Bool,
        hasError: Bool,
        hasActiveTool: Bool,
        toolCount: Int
    ) -> HermesVoiceActivitySignal {
        let phase: HermesVoiceActivityPhase
        if !isConversing {
            phase = .ended
        } else if hasError, !isSpeaking {
            phase = .failed
        } else if isSpeaking {
            phase = .speaking
        } else if hasActiveTool {
            phase = .usingTools
        } else if isThinking {
            phase = .thinking
        } else if isListening {
            phase = .listening
        } else {
            phase = .paused
        }

        return HermesVoiceActivitySignal(
            phase: phase,
            toolCount: max(0, toolCount),
            isMuted: isMuted
        )
    }
}

enum HermesVoiceActivityPrivacy {
    static func endpointName(_ rawValue: String) -> String {
        let singleLine = rawValue
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = singleLine.isEmpty ? "Hermes" : singleLine
        return String(fallback.prefix(32))
    }
}

enum HermesVoiceActivityDeepLink {
    static let scheme = "hermes-companion"
    static let host = "voice"

    static func url(endpointID: UUID) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [
            URLQueryItem(name: "endpoint", value: endpointID.uuidString)
        ]
        return components.url
    }

    static func endpointID(from url: URL) -> UUID? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == host,
              let rawID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "endpoint" })?.value
        else { return nil }
        return UUID(uuidString: rawID)
    }
}

enum HermesVoiceActivityAction: String, Codable, Equatable, Sendable {
    case mute
    case resume
    case end
}

struct HermesVoiceActivityActionRequest: Codable, Equatable, Sendable {
    let conversationID: UUID
    let endpointID: UUID
    let action: HermesVoiceActivityAction
    let createdAt: Date
}

enum HermesVoiceActivityActionHandoff {
    static let key = "voice_activity_action_v1"
    static let maximumAge: TimeInterval = 30

    static func request(
        _ action: HermesVoiceActivityAction,
        conversationID: UUID,
        endpointID: UUID,
        at date: Date = Date(),
        defaults: UserDefaults = SharedDefaults.shared
    ) {
        let request = HermesVoiceActivityActionRequest(
            conversationID: conversationID,
            endpointID: endpointID,
            action: action,
            createdAt: date
        )
        defaults.set(try? JSONEncoder().encode(request), forKey: key)
    }

    static func consume(
        conversationID: UUID,
        endpointID: UUID,
        now: Date = Date(),
        defaults: UserDefaults = SharedDefaults.shared
    ) -> HermesVoiceActivityAction? {
        guard let data = defaults.data(forKey: key),
              let request = try? JSONDecoder().decode(
                HermesVoiceActivityActionRequest.self,
                from: data
              )
        else { return nil }

        defaults.removeObject(forKey: key)
        guard request.conversationID == conversationID,
              request.endpointID == endpointID,
              now.timeIntervalSince(request.createdAt) >= 0,
              now.timeIntervalSince(request.createdAt) <= maximumAge
        else { return nil }
        return request.action
    }
}
