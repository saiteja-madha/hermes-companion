import ActivityKit
import Combine
import Foundation

/// Owns the single Live Activity for the currently active voice conversation.
/// All state is privacy-reduced before it reaches this boundary.
@MainActor
final class VoiceLiveActivityCoordinator: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var lastError: String?

    private var activity: Activity<HermesVoiceActivityAttributes>?
    private var conversationID: UUID?
    private var endpointID: UUID?
    private var lastSignal: HermesVoiceActivitySignal?
    private var updateGeneration = 0

    /// A Live Activity can outlive a process crash or force-quit, but an
    /// in-process microphone session cannot. Clear those orphaned cards at the
    /// next app launch before a new conversation is allowed to start.
    static func endOrphanedActivitiesAtLaunch() {
        let finalContent = ActivityContent(
            state: HermesVoiceActivityAttributes.ContentState.ended(),
            staleDate: nil
        )
        Task {
            for existing in Activity<HermesVoiceActivityAttributes>.activities {
                await existing.end(finalContent, dismissalPolicy: .immediate)
            }
        }
    }

    func start(
        conversationID: UUID,
        endpoint: VoiceEndpointBinding,
        signal: HermesVoiceActivitySignal,
        now: Date = Date()
    ) {
        if self.conversationID == conversationID,
           endpointID == endpoint.endpointID,
           activity?.activityState == .active {
            update(signal)
            return
        }

        end()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            lastError = "Live Activities are disabled for Hermes."
            return
        }

        let attributes = HermesVoiceActivityAttributes(
            conversationID: conversationID,
            endpointID: endpoint.endpointID,
            endpointName: HermesVoiceActivityPrivacy.endpointName(endpoint.displayName),
            startedAt: now
        )
        let state = contentState(for: signal, at: now)

        do {
            let requested = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            activity = requested
            self.conversationID = conversationID
            endpointID = endpoint.endpointID
            lastSignal = signal
            isActive = true
            lastError = nil
            endOrphanedActivities(except: requested.id)
            FileLogger.shared.log("VoiceActivity: started for \(attributes.endpointName)")
        } catch {
            activity = nil
            self.conversationID = nil
            endpointID = nil
            lastSignal = nil
            isActive = false
            lastError = "Could not start Live Activity: \(error.localizedDescription)"
            FileLogger.shared.log("VoiceActivity: start failed: \(error.localizedDescription)")
        }
    }

    func update(_ signal: HermesVoiceActivitySignal, now: Date = Date()) {
        guard signal != lastSignal else { return }
        guard let activity, activity.activityState == .active else {
            isActive = false
            return
        }

        lastSignal = signal
        updateGeneration += 1
        let generation = updateGeneration
        let activityID = activity.id
        let content = ActivityContent(
            state: contentState(for: signal, at: now),
            staleDate: nil
        )
        Task { @MainActor [weak self] in
            guard let self,
                  generation == self.updateGeneration,
                  self.activity?.id == activityID
            else { return }
            await activity.update(content)
        }
    }

    func end() {
        updateGeneration += 1
        let endingActivity = activity
        activity = nil
        conversationID = nil
        endpointID = nil
        lastSignal = nil
        isActive = false

        guard let endingActivity else { return }
        let finalContent = ActivityContent(
            state: HermesVoiceActivityAttributes.ContentState.ended(),
            staleDate: nil
        )
        Task {
            await endingActivity.end(finalContent, dismissalPolicy: .immediate)
        }
        FileLogger.shared.log("VoiceActivity: ended")
    }

    private func contentState(
        for signal: HermesVoiceActivitySignal,
        at date: Date
    ) -> HermesVoiceActivityAttributes.ContentState {
        HermesVoiceActivityAttributes.ContentState(
            phase: signal.phase,
            toolCount: signal.toolCount,
            isMuted: signal.isMuted,
            updatedAt: date
        )
    }

    private func endOrphanedActivities(except currentID: String) {
        let finalContent = ActivityContent(
            state: HermesVoiceActivityAttributes.ContentState.ended(),
            staleDate: nil
        )
        Task {
            for existing in Activity<HermesVoiceActivityAttributes>.activities
            where existing.id != currentID {
                await existing.end(finalContent, dismissalPolicy: .immediate)
            }
        }
    }
}
