import ActivityKit
import AppIntents
import Foundation

/// Interactive Live Activity actions run in the main app process because they
/// conform to `LiveActivityIntent`. The exact conversation and endpoint IDs are
/// mandatory so a stale Dynamic Island can never control a newer session.
struct SetHermesVoiceMuteIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Mute Hermes Voice"
    static var description = IntentDescription("Mute or resume one active Hermes voice conversation.")

    @Parameter(title: "Conversation")
    var conversationID: String

    @Parameter(title: "Server")
    var endpointID: String

    @Parameter(title: "Muted")
    var muted: Bool

    init() {
        conversationID = ""
        endpointID = ""
        muted = false
    }

    init(conversationID: UUID, endpointID: UUID, muted: Bool) {
        self.conversationID = conversationID.uuidString
        self.endpointID = endpointID.uuidString
        self.muted = muted
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let conversationID = UUID(uuidString: conversationID),
              let endpointID = UUID(uuidString: endpointID)
        else { return .result() }

        HermesVoiceActivityActionHandoff.request(
            muted ? .mute : .resume,
            conversationID: conversationID,
            endpointID: endpointID
        )
        NotificationCenter.default.post(name: .voiceActivityAction, object: nil)
        return .result()
    }
}

struct EndHermesVoiceActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End Hermes Voice"
    static var description = IntentDescription("End one active Hermes voice conversation.")

    @Parameter(title: "Conversation")
    var conversationID: String

    @Parameter(title: "Server")
    var endpointID: String

    init() {
        conversationID = ""
        endpointID = ""
    }

    init(conversationID: UUID, endpointID: UUID) {
        self.conversationID = conversationID.uuidString
        self.endpointID = endpointID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let conversationID = UUID(uuidString: conversationID),
              let endpointID = UUID(uuidString: endpointID)
        else { return .result() }

        HermesVoiceActivityActionHandoff.request(
            .end,
            conversationID: conversationID,
            endpointID: endpointID
        )
        NotificationCenter.default.post(name: .voiceActivityAction, object: nil)
        return .result()
    }
}
