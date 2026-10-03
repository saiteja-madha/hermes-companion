import ActivityKit
import SwiftUI
import WidgetKit

struct HermesVoiceLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HermesVoiceActivityAttributes.self) { context in
            HermesVoiceLockScreenView(context: context)
                .activityBackgroundTint(HermesVoiceActivityTheme.background)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(HermesVoiceActivityDeepLink.url(
                    endpointID: context.attributes.endpointID
                ))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HERMES")
                            .font(.caption2.weight(.bold).monospaced())
                            .foregroundStyle(HermesVoiceActivityTheme.secondary)
                        Text(context.attributes.endpointName)
                            .font(.caption.weight(.semibold).monospaced())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .padding(.leading, 12)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    HermesVoicePhaseLabel(state: context.state)
                        .padding(.trailing, 12)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        HermesVoiceSignalRail(phase: context.state.phase)
                        HermesVoiceActivityControls(context: context)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                }
            } compactLeading: {
                Image(systemName: context.state.phase.symbolName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(context.state.phase.tint)
                    .accessibilityLabel(context.state.phase.title)
            } compactTrailing: {
                Text(context.attributes.endpointName.prefix(8).uppercased())
                    .font(.caption2.weight(.semibold).monospaced())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .accessibilityLabel("Hermes server \(context.attributes.endpointName)")
            } minimal: {
                Image(systemName: context.state.phase.symbolName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(context.state.phase.tint)
                    .accessibilityLabel(context.state.phase.title)
            }
            .widgetURL(HermesVoiceActivityDeepLink.url(
                endpointID: context.attributes.endpointID
            ))
            .keylineTint(context.state.phase.tint)
        }
    }
}

private struct HermesVoiceLockScreenView: View {
    let context: ActivityViewContext<HermesVoiceActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: context.state.phase.symbolName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(context.state.phase.tint)
                    .frame(width: 36, height: 36)
                    .background(context.state.phase.tint.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("HERMES · \(context.attributes.endpointName.uppercased())")
                        .font(.caption2.weight(.bold).monospaced())
                        .foregroundStyle(HermesVoiceActivityTheme.secondary)
                        .lineLimit(1)
                    Text(context.state.isMuted ? "Microphone muted" : context.state.phase.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(HermesVoiceActivityTheme.secondary)
                    .multilineTextAlignment(.trailing)
            }

            HermesVoiceSignalRail(phase: context.state.phase)

            HStack(spacing: 10) {
                if context.state.toolCount > 0 {
                    Label("\(context.state.toolCount) tool\(context.state.toolCount == 1 ? "" : "s")", systemImage: "wrench.and.screwdriver")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(HermesVoiceActivityTheme.secondary)
                }
                Spacer()
                HermesVoiceActivityControls(context: context)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .contain)
    }
}

private struct HermesVoiceActivityControls: View {
    let context: ActivityViewContext<HermesVoiceActivityAttributes>

    var body: some View {
        HStack(spacing: 10) {
            Button(intent: SetHermesVoiceMuteIntent(
                conversationID: context.attributes.conversationID,
                endpointID: context.attributes.endpointID,
                muted: !context.state.isMuted
            )) {
                Label(
                    context.state.isMuted ? "Resume" : "Mute",
                    systemImage: context.state.isMuted ? "mic.fill" : "mic.slash.fill"
                )
                .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(HermesVoiceActivityTheme.accent)

            Button(intent: EndHermesVoiceActivityIntent(
                conversationID: context.attributes.conversationID,
                endpointID: context.attributes.endpointID
            )) {
                Label("End", systemImage: "xmark.circle.fill")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }
}

private struct HermesVoicePhaseLabel: View {
    let state: HermesVoiceActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(state.isMuted ? "MUTED" : state.phase.title.uppercased())
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(state.phase.tint)
            if state.toolCount > 0 {
                Text("\(state.toolCount) TOOLS")
                    .font(.caption2.monospaced())
                    .foregroundStyle(HermesVoiceActivityTheme.secondary)
            }
        }
    }
}

private struct HermesVoiceSignalRail: View {
    let phase: HermesVoiceActivityPhase

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(phase.tint.opacity(index < phase.railCount ? 0.9 : 0.18))
                    .frame(height: 3)
            }
        }
        .accessibilityHidden(true)
    }
}

private enum HermesVoiceActivityTheme {
    static let accent = Color(red: 0.0, green: 1.0, blue: 0.25)
    static let secondary = Color.white.opacity(0.62)
    static let background = Color(red: 0.01, green: 0.06, blue: 0.03)
}

private extension HermesVoiceActivityPhase {
    var title: String {
        switch self {
        case .listening: "Listening"
        case .thinking: "Thinking"
        case .usingTools: "Using tools"
        case .speaking: "Speaking"
        case .paused: "Paused"
        case .reconnecting: "Reconnecting"
        case .failed: "Needs attention"
        case .ended: "Ended"
        }
    }

    var symbolName: String {
        switch self {
        case .listening: "waveform"
        case .thinking: "ellipsis.bubble.fill"
        case .usingTools: "wrench.and.screwdriver.fill"
        case .speaking: "speaker.wave.2.fill"
        case .paused: "pause.fill"
        case .reconnecting: "arrow.triangle.2.circlepath"
        case .failed: "exclamationmark.triangle.fill"
        case .ended: "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .listening: HermesVoiceActivityTheme.accent
        case .thinking: .cyan
        case .usingTools: .orange
        case .speaking: .mint
        case .paused: .yellow
        case .reconnecting: .blue
        case .failed: .red
        case .ended: .gray
        }
    }

    var railCount: Int {
        switch self {
        case .listening: 8
        case .thinking: 4
        case .usingTools: 6
        case .speaking: 7
        case .paused: 2
        case .reconnecting: 3
        case .failed: 1
        case .ended: 8
        }
    }
}
