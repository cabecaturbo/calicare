import UIKit

/// The round Log button's icon: the palm with "Log" under it, drawn as one
/// template image, because iOS shows only the icon (not the title) in that circle.
enum LogTabIcon {
    static let image: UIImage = {
        let symbol = UIImage(
            systemName: "hand.raised.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        ) ?? UIImage()
        let text = NSAttributedString(string: "Log", attributes: [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.black,
        ])
        let textSize = text.size()
        let size = CGSize(width: max(symbol.size.width, textSize.width), height: symbol.size.height + 1 + textSize.height)
        let drawn = UIGraphicsImageRenderer(size: size).image { _ in
            symbol.withTintColor(.black).draw(at: CGPoint(x: (size.width - symbol.size.width) / 2, y: 0))
            text.draw(at: CGPoint(x: (size.width - textSize.width) / 2, y: symbol.size.height + 1))
        }
        return drawn.withRenderingMode(.alwaysTemplate)
    }()
}
