import Core
import Messages
import SwiftUI
import UIKit

/// CaliCare in Messages: this week's card for each child, sent as a compact
/// bubble. Tapping a bubble opens the full card, drawn from the message
/// itself, so it works offline and for anyone who has CaliCare.
final class MessagesViewController: MSMessagesAppViewController {
    private let model = MessagesModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        FontRegistry.registerAll()
        let root = MessagesRootView(
            model: model,
            onSend: { [weak self] card in self?.send(card) },
            onBack: { [weak self] in
                self?.model.opened = nil
                self?.requestPresentationStyle(.compact)
            }
        )
        .nightAwarePalette()
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        open(conversation.selectedMessage)
        Task { await model.load() }
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        open(message)
    }

    /// Shows the full card for a tapped bubble.
    private func open(_ message: MSMessage?) {
        guard let url = message?.url, let card = WeeklyCard(url: url) else { return }
        model.opened = card
        requestPresentationStyle(.expanded)
    }

    /// Adds the compact bubble to the message field; the person taps Send.
    private func send(_ card: WeeklyCard) {
        guard let conversation = activeConversation, let url = card.url else { return }
        let layout = MSMessageTemplateLayout()
        layout.image = WeeklyCardRenderer.bubbleImage(for: card)
        layout.caption = "\(card.childName) · \(card.dateRange)"
        layout.subcaption = "Tap to see full week"
        let message = MSMessage(session: MSSession())
        message.layout = layout
        message.url = url
        message.summaryText = "\(card.childName)'s week: \(card.headline)"
        Task {
            try? await conversation.insert(message)
            requestPresentationStyle(.compact)
        }
    }
}
