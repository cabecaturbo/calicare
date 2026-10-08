import Core
import SwiftUI

/// The extension's screen: either the full card for a tapped bubble, or this
/// week's cards to send.
struct MessagesRootView: View {
    @Environment(\.palette) private var palette
    let model: MessagesModel
    let onSend: (WeeklyCard) -> Void
    let onSendText: (String) -> Void
    let onBack: () -> Void

    var body: some View {
        Group {
            if let card = model.opened {
                fullCard(card)
            } else {
                picker
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .paperBackground()
    }

    private var picker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x4) {
                if !model.lastNights.isEmpty {
                    Text("Last night")
                        .textStyle(.title)
                        .foregroundStyle(palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(model.lastNights) { night in
                        Button { onSendText(night.text) } label: {
                            Text(night.text)
                                .textStyle(.body)
                                .foregroundStyle(palette.ink)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(Spacing.x4)
                                .overlay(RoundedRectangle(cornerRadius: Corner.card).strokeBorder(palette.hairline, lineWidth: Rule.width))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Adds this text to the message.")
                    }
                }
                Text("This week")
                    .textStyle(.title)
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
                if model.hasLoaded && model.cards.isEmpty {
                    Text("Add your child in Cali Care to share their week.")
                        .textStyle(.body)
                        .foregroundStyle(palette.graphite)
                }
                ForEach(Array(model.cards.enumerated()), id: \.offset) { _, card in
                    Button { onSend(card) } label: {
                        Scaled(size: WeeklyBubbleView.size) { WeeklyBubbleView(card: card) }
                            .overlay(Rectangle().strokeBorder(palette.hairline, lineWidth: Rule.width))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Send \(card.childName)'s week: \(card.headline)")
                }
            }
            .padding(Spacing.x4)
        }
    }

    private func fullCard(_ card: WeeklyCard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x4) {
                Button("This week's cards", action: onBack)
                    .buttonStyle(.textLink)
                Scaled(size: WeeklyCardView.size) { WeeklyCardView(card: card) }
                    .overlay(Rectangle().strokeBorder(palette.hairline, lineWidth: Rule.width))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(summary(card))
            }
            .padding(Spacing.x4)
        }
    }

    private func summary(_ card: WeeklyCard) -> String {
        var parts = ["\(card.childName), \(card.dateRange). \(card.headline)."]
        if card.hasSummary {
            parts.append("\(card.goodNights) good nights of 7. \(card.itchyWakeUps) itchy wake-ups.")
        }
        if let line = card.worthWatching { parts.append(line) }
        return parts.joined(separator: " ")
    }
}

/// Draws a fixed-size card scaled to the available width.
private struct Scaled<Content: View>: View {
    let size: CGSize
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / size.width
            content
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: proxy.size.width, height: size.height * scale, alignment: .topLeading)
        }
        .aspectRatio(size.width / size.height, contentMode: .fit)
    }
}
