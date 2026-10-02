import Core
import SwiftUI

/// Progress's "Changes" (prompt 4.6): what changed in the child's care, newest
/// first, and, when skin or nights turned rougher, what changed in the week
/// before. It notices; it never says why.
struct ChangesSection: View {
    @Environment(\.palette) private var palette
    let changes: [CareChange]
    let rougherSince: CareDay?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            if let rougherSince {
                let before = CareChanges.before(rougherSince, in: changes)
                VStack(alignment: .leading, spacing: Spacing.x1) {
                    Text("Rougher since \(rougherSince.noon().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))")
                        .textStyle(.body)
                        .foregroundStyle(palette.ochre)
                    Text(before.isEmpty ? "Nothing in your plan changed in the week before." : "In the week before:")
                        .textStyle(.meta)
                        .foregroundStyle(palette.graphite)
                    ForEach(before) { change in
                        Text("\(change.date.formatted(.dateTime.month(.abbreviated).day())) · \(change.text)")
                            .textStyle(.meta)
                            .foregroundStyle(palette.ink)
                    }
                }
                .padding(Spacing.x4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.oat, in: RoundedRectangle(cornerRadius: Corner.card))
                .accessibilityElement(children: .combine)
            }
            if !changes.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Changes")
                        .textStyle(.section)
                        .foregroundStyle(palette.ink)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, Spacing.x2)
                    ForEach(changes.prefix(8)) { change in
                        HStack(alignment: .firstTextBaseline) {
                            Text(change.text).textStyle(.body).foregroundStyle(palette.ink)
                            Spacer()
                            Text(change.date.formatted(.dateTime.month(.abbreviated).day()))
                                .textStyle(.meta)
                                .foregroundStyle(palette.graphite)
                        }
                        .frame(minHeight: 44)
                        .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
                    }
                }
            }
        }
    }
}
