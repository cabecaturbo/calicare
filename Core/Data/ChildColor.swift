import Foundation

/// The color tag that tells children apart. Stored on Child as `colorTag`.
public enum ChildColor: String, Sendable, CaseIterable, Identifiable {
    case sage, clay, moss, sand

    public static let standard: ChildColor = .sage

    public var id: String { rawValue }

    /// Unknown or missing tags fall back to sage.
    public init(tag: String?) {
        self = tag.flatMap(ChildColor.init(rawValue:)) ?? .standard
    }

    /// Stored tags predate the notebook palette, so the spoken name follows the color shown.
    public var name: String {
        switch self {
        case .sage: "Clay"
        case .clay: "Ochre"
        case .moss: "Graphite"
        case .sand: "Oat"
        }
    }
}
