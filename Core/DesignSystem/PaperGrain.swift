import SwiftUI
import UIKit

/// A very faint static paper grain: 3.5% opacity, multiplied onto paper or oat.
/// Never over shared report cards, never in widgets.
public struct PaperGrain: View {
    public init() {}

    public var body: some View {
        if let tile = Self.tile {
            Image(uiImage: tile)
                .resizable(resizingMode: .tile)
                .blendMode(.multiply)
                .opacity(0.035)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private static let tile = UIImage(named: "PaperGrain", in: Bundle(for: BundleToken.self), with: nil)
}

private final class BundleToken {}
