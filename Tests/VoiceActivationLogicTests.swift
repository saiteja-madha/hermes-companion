import XCTest
import AVFoundation
@testable import HermesCompanion

final class VoiceActivationLogicTests: XCTestCase {
    func testBackgroundLifecyclePreservesOnlyAnExplicitConversation() {
        XCTAssertTrue(
            VoiceConversationLifecyclePolicy.shouldPreserveConversationInBackground(
                isConversing: true
            )
        )
        XCTAssertFalse(
            VoiceConversationLifecyclePolicy.shouldPreserveConversationInBackground(
                isConversing: false
            ),
            "Background audio must not turn idle voice mode into an always-on microphone"
        )
    }

    func testForegroundRecoveryStartsOnlyFromAnIdleConversationPhase() {
        XCTAssertTrue(VoiceConversationLifecyclePolicy.shouldRecoverListening(
            isConversing: true, isListening: false, isSpeaking: false, isThinking: false
        ))
        XCTAssertFalse(VoiceConversationLifecyclePolicy.shouldRecoverListening(
            isConversing: false, isListening: false, isSpeaking: false, isThinking: false
        ))
        XCTAssertFalse(VoiceConversationLifecyclePolicy.shouldRecoverListening(
            isConversing: true, isListening: true, isSpeaking: false, isThinking: false
        ))
        XCTAssertFalse(VoiceConversationLifecyclePolicy.shouldRecoverListening(
            isConversing: true, isListening: false, isSpeaking: true, isThinking: false
        ))
        XCTAssertFalse(VoiceConversationLifecyclePolicy.shouldRecoverListening(
            isConversing: true, isListening: false, isSpeaking: false, isThinking: true
        ))
    }

    @MainActor
    func testBackgroundTransitionDoesNotEndExplicitConversation() {
        let manager = VoiceConversationManager()
        manager.isConversing = true

        manager.handleAppBackground()

        XCTAssertTrue(manager.isConversing)
        manager.stopConversation()
    }

    func testVoiceEndpointBindingMatchesOnlyCapturedServer() {
        let linuxID = UUID()
        let linux = ConnectionConfig(endpointID: linuxID, baseURL: "https://linux-hermes.example/", apiKey: "linux-key", label: "Linux")
        let sameLinux = ConnectionConfig(endpointID: linuxID, baseURL: "https://linux-hermes.example", apiKey: "rotated-key", label: "Linux renamed")
        let mac = ConnectionConfig(baseURL: "https://mac-hermes.example", apiKey: "mac-key", label: "Mac")
        let binding = VoiceEndpointBinding(config: linux)

        XCTAssertTrue(binding.matches(sameLinux), "A trailing slash or credential rotation must not change endpoint identity")
        XCTAssertFalse(binding.matches(mac), "A voice turn must never follow the globally selected server")
        XCTAssertFalse(binding.matches(nil))
        XCTAssertEqual(binding.displayName, "Linux")
    }

    func testVoiceEndpointBindingFallsBackToHostWhenLabelIsBlank() {
        let config = ConnectionConfig(baseURL: "https://hermes.example:8642/", apiKey: "key", label: "  ")

        XCTAssertEqual(VoiceEndpointBinding(config: config).displayName, "hermes.example")
    }

    func testVoiceEndpointBindingRejectsReusedURLWithDifferentIdentity() {
        let first = ConnectionConfig(baseURL: "https://hermes.example", apiKey: "first", label: "Old")
        let replacement = ConnectionConfig(baseURL: "https://hermes.example", apiKey: "second", label: "Replacement")

        XCTAssertFalse(VoiceEndpointBinding(config: first).matches(replacement))
    }

    func testExplicitVoiceLaunchNeverFallsBackToCurrentOrPreferredEndpoint() {
        let linux = ConnectionConfig(baseURL: "https://linux.example", apiKey: "linux", label: "Linux")
        let mac = ConnectionConfig(baseURL: "https://mac.example", apiKey: "mac", label: "Mac")

        XCTAssertEqual(
            VoiceLaunchEndpointResolver.resolve(
                requestedID: linux.endpointID,
                preferredID: mac.endpointID,
                current: mac,
                saved: [mac, linux]
            ),
            linux
        )
        XCTAssertNil(
            VoiceLaunchEndpointResolver.resolve(
                requestedID: UUID(),
                preferredID: mac.endpointID,
                current: mac,
                saved: [mac, linux]
            ),
            "A removed explicit endpoint must not fall through to another Hermes instance"
        )
    }

    func testGenericVoiceLaunchUsesPreferredThenCurrentEndpoint() {
        let linux = ConnectionConfig(baseURL: "https://linux.example", apiKey: "linux", label: "Linux")
        let mac = ConnectionConfig(baseURL: "https://mac.example", apiKey: "mac", label: "Mac")

        XCTAssertEqual(
            VoiceLaunchEndpointResolver.resolve(
                requestedID: nil,
                preferredID: linux.endpointID,
                current: mac,
                saved: [mac, linux]
            ),
            linux
        )
        XCTAssertEqual(
            VoiceLaunchEndpointResolver.resolve(
                requestedID: nil,
                preferredID: nil,
                current: mac,
                saved: [mac, linux]
            ),
            mac
        )
    }

    func testPreferredVoiceEndpointIDRoundTripsWithoutCredentials() {
        let name = "voice-endpoint-preference-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let endpointID = UUID()

        VoiceActivationControlConstants.setPreferredEndpointID(endpointID, in: defaults)

        XCTAssertEqual(VoiceActivationControlConstants.preferredEndpointID(in: defaults), endpointID)
        XCTAssertEqual(defaults.dictionaryRepresentation().count, 1)
    }

    func testVoiceEndpointCatalogAndPendingLaunchContainOnlyPublicIdentity() {
        let name = "voice-endpoint-catalog-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let endpointID = UUID()
        let endpoint = VoiceEndpointDescriptor(id: endpointID, name: "Linux")

        VoiceActivationControlConstants.cacheEndpoints([endpoint], in: defaults)
        VoiceActivationControlConstants.requestVoiceLaunch(endpointID: endpointID, in: defaults)

        XCTAssertEqual(VoiceActivationControlConstants.cachedEndpoints(in: defaults), [endpoint])
        XCTAssertEqual(VoiceActivationControlConstants.pendingEndpointID(in: defaults), endpointID)
        XCTAssertTrue(defaults.bool(forKey: VoiceActivationControlConstants.openVoicePageKey))
        let serialized = String(data: defaults.data(forKey: VoiceActivationControlConstants.endpointCatalogKey)!, encoding: .utf8)!
        XCTAssertFalse(serialized.contains("apiKey"))
        XCTAssertFalse(serialized.contains("baseURL"))

        VoiceActivationControlConstants.clearPendingVoiceLaunch(in: defaults)
        XCTAssertNil(VoiceActivationControlConstants.pendingEndpointID(in: defaults))
        XCTAssertFalse(defaults.bool(forKey: VoiceActivationControlConstants.openVoicePageKey))
    }

    @MainActor
    func testIdleVoiceControllersIgnoreSystemAudioInterruptionsAndCleanup() throws {
        let audio = AVAudioSession.sharedInstance()
        let category = audio.category
        let mode = audio.mode
        let options = audio.categoryOptions
        defer { try? audio.setCategory(category, mode: mode, options: options) }
        let phoneVoice = VoiceConversationManager()
        let carVoice = VoiceConversationManager()
        try audio.setCategory(.ambient, mode: .default)

        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification,
            object: audio, userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        XCTAssertEqual(audio.category, .ambient, "Idle observers must not reconfigure keyboard or other app audio")
        phoneVoice.stopConversation()
        carVoice.stopListening()
        carVoice.stopConversation()
        XCTAssertEqual(audio.category, .ambient, "Stopping an unused voice controller must leave audio alone")
    }

    @MainActor
    func testTextModeSurvivesAutomaticWakeListenerResumes() {
        let listener = WakePhraseListener()
        listener.suspendForTextInput()
        listener.start()
        listener.resume()
        listener.resumeFromBackground()
        listener.stop()
        XCTAssertTrue(listener.isSuspendedForTextInput)
        listener.allowAfterExplicitVoiceRequest()
        XCTAssertFalse(listener.isSuspendedForTextInput)
    }

    @MainActor
    func testTextBackgroundLifecyclePreservesAudioCategory() throws {
        let audio = AVAudioSession.sharedInstance()
        let originalCategory = audio.category
        let originalMode = audio.mode
        let originalOptions = audio.categoryOptions
        defer { try? audio.setCategory(originalCategory, mode: originalMode, options: originalOptions) }
        try audio.setCategory(.ambient, mode: .default)
        let client = HermesAPIClient(config: ConnectionConfig(
            baseURL: "https://hermes.invalid", apiKey: "", label: "Test"))
        let store = AppStore(client: client)
        store.beginBackgroundKeepAlive()
        XCTAssertEqual(audio.category, .ambient)
        store.endBackgroundTask()
        XCTAssertEqual(audio.category, .ambient)
        store.handleForegroundReturn()
        XCTAssertEqual(audio.category, .ambient)
    }

    func testWakeListeningRequiresFreshOptIn() {
        let name = "wake-consent-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        defaults.set(true, forKey: "hey_hermes_enabled")
        SharedDefaults.migrateWakeListeningConsent(in: defaults)
        XCTAssertFalse(defaults.bool(forKey: "hey_hermes_enabled"))

        defaults.set(true, forKey: "hey_hermes_enabled")
        SharedDefaults.migrateWakeListeningConsent(in: defaults)
        XCTAssertTrue(defaults.bool(forKey: "hey_hermes_enabled"))
    }

    func testNewInstallDoesNotEnableWakeListening() {
        let name = "wake-consent-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        SharedDefaults.migrateWakeListeningConsent(in: defaults)
        XCTAssertFalse(defaults.bool(forKey: "hey_hermes_enabled"))
    }

    @MainActor
    func testIdleWakeListenerDoesNotReleaseAnotherAudioSession() {
        var releases = 0
        let listener = WakePhraseListener(deactivateAudioSession: { releases += 1 })
        listener.resumeFromBackground()
        listener.pause()
        listener.resume()
        listener.stop()
        XCTAssertEqual(releases, 0)
    }

    @MainActor
    func testCarPlayImplementsSystemDisconnectCallback() {
        let delegate = CarPlaySceneDelegate()
        XCTAssertTrue(delegate.responds(to: NSSelectorFromString("templateApplicationScene:didDisconnectInterfaceController:")))
        XCTAssertTrue(delegate.responds(to: NSSelectorFromString("templateApplicationScene:didConnectInterfaceController:")))
    }

    func testEndpointingAllowsNaturalPauses() {
        XCTAssertGreaterThanOrEqual(VoiceEndpointingPolicy.silenceTimeout, 1.5)
    }

    func testWakePhraseMatchesCaseAndPunctuation() {
        XCTAssertTrue(WakePhraseParser.containsWakePhrase("Hey Hermes"))
        XCTAssertTrue(WakePhraseParser.containsWakePhrase("hey, hermes!"))
        XCTAssertTrue(WakePhraseParser.containsWakePhrase("Okay hey Hermes can you help me"))
    }

    func testWakePhraseRejectsNearMatches() {
        XCTAssertFalse(WakePhraseParser.containsWakePhrase("Hermes is useful"))
        XCTAssertFalse(WakePhraseParser.containsWakePhrase("Hey Herman"))
    }
}
