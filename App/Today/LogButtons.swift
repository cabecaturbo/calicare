import Core
import SwiftUI

/// Large one-tap log buttons. One column and bigger at night or with large text.
struct LogButtons: View {
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    let isDaytime: Bool
    let onLog: (LogType, LogValue?) -> Void

    private struct Choice: Identifiable {
        let type: LogType
        let title: String
        let spoken: String
        var id: LogType { type }
    }

    private static let choices = [
        Choice(type: .itchEpisode, title: "Itchy", spoken: "Log itching"),
        Choice(type: .flare, title: "Flare", spoken: "Log a flare"),
        Choice(type: .bowelMovement, title: "Bowel movement", spoken: "Log a bowel movement"),
        Choice(type: .routineDone, title: "Routine done", spoken: "Log routine done"),
    ]

    private var singleColumn: Bool { palette.isNight || typeSize.isAccessibilitySize }
    private var height: CGFloat { palette.isNight ? TouchTarget.logButtonNight : TouchTarget.logButtonDay }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.s), count: singleColumn ? 1 : 2)
            LazyVGrid(columns: columns, spacing: Spacing.s) {
                ForEach(Self.choices) { choice in
                    button(for: choice)
                }
            }
            nightRating
        }
    }

    private func button(for choice: Choice) -> some View {
        let prominent = choice.type == .itchEpisode
        return Button {
            onLog(choice.type, value(for: choice.type))
        } label: {
            Group {
                if singleColumn {
                    HStack(spacing: Spacing.m) {
                        icon(choice.type)
                        title(choice.title)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Spacing.l)
                } else {
                    VStack(spacing: Spacing.xs) {
                        icon(choice.type)
                        title(choice.title)
                    }
                    .padding(.horizontal, Spacing.s)
                }
            }
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(prominent ? palette.onAccent : palette.ink)
            .background(
                prominent ? palette.accent : palette.card,
                in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.spoken)
    }

    private func icon(_ type: LogType) -> some View {
        Image(systemName: type.symbol)
            .font(.title2.weight(.medium))
            .accessibilityHidden(true)
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(palette.isNight ? Typography.title3 : Typography.button)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func value(for type: LogType) -> LogValue? {
        type == .routineDone ? .routine(RoutineTime.likely(at: .now)) : nil
    }

    private var nightRating: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(isDaytime ? "How was last night?" : "How's the night going?")
                .font(Typography.headline)
                .foregroundStyle(palette.ink)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.s) { ratingButtons }
                VStack(spacing: Spacing.s) { ratingButtons }
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private var ratingButtons: some View {
        ForEach(NightRating.allCases, id: \.self) { rating in
            Button {
                onLog(.nightRating, .night(rating))
            } label: {
                Text(rating.title)
                    .font(Typography.button)
                    .foregroundStyle(palette.sageDark)
                    .lineLimit(1)
                    .padding(.horizontal, Spacing.m)
                    .frame(maxWidth: .infinity, minHeight: palette.isNight ? TouchTarget.night : TouchTarget.minimum)
                    .background(palette.sand, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log a \(rating.rawValue) night")
        }
    }
}
