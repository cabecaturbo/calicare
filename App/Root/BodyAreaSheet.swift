import Core
import SwiftUI

/// "Add where" after a flare: a simple front and back outline. Tap areas, then
/// Save. Optional, never required.
struct BodyAreaSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(TodayModel.self) private var model
    let entry: LogEntry
    @State private var selected: Set<BodyArea>
    @State private var side: BodyOutline.Side = .front
    @State private var saving = false

    init(entry: LogEntry) {
        self.entry = entry
        _selected = State(initialValue: Set(entry.bodyAreas))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.x5) {
                    Picker("Side", selection: $side) {
                        Text("Front").tag(BodyOutline.Side.front)
                        Text("Back").tag(BodyOutline.Side.back)
                    }
                    .pickerStyle(.segmented)

                    BodyOutline(side: side, selected: $selected)

                    Text(summary)
                        .textStyle(.body)
                        .foregroundStyle(selected.isEmpty ? palette.graphite : palette.ink)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, Spacing.margin)
                .padding(.vertical, Spacing.x4)
            }
            .paperBackground(.oat)
            .navigationTitle("Where was the flare?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(saving)
                }
            }
        }
        .tint(palette.indigo)
        .presentationDetents([.large])
    }

    /// "Face, hands", in the list's order.
    private var summary: String {
        let words = BodyArea.allCases.filter(selected.contains).map(\.words)
        guard let first = words.first else { return "Tap where it was." }
        return ([first.prefix(1).uppercased() + first.dropFirst()] + words.dropFirst()).joined(separator: ", ")
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let areas = BodyArea.allCases.filter(selected.contains)
        if await model.setBodyAreas(areas, on: entry) { dismiss() }
    }
}

/// A plain figure made of rounded shapes. Each shape is one tappable area.
struct BodyOutline: View {
    enum Side { case front, back }

    @Environment(\.palette) private var palette
    let side: Side
    @Binding var selected: Set<BodyArea>

    /// One tappable shape, in a 200 × 360 frame.
    private struct Part: Identifiable {
        let area: BodyArea
        let rect: CGRect
        var corner: CGFloat = 12
        var id: String { "\(area.rawValue)-\(rect.minX)-\(rect.minY)" }
    }

    private var parts: [Part] {
        let head = Part(area: side == .front ? .face : .back, rect: CGRect(x: 76, y: 0, width: 48, height: 54), corner: 24)
        let common: [Part] = [
            Part(area: .neck, rect: CGRect(x: 88, y: 56, width: 24, height: 16), corner: 6),
            Part(area: side == .front ? .torso : .back, rect: CGRect(x: 62, y: 74, width: 76, height: 104), corner: 16),
            Part(area: .arms, rect: CGRect(x: 30, y: 76, width: 28, height: 50)),
            Part(area: .arms, rect: CGRect(x: 142, y: 76, width: 28, height: 50)),
            Part(area: side == .front ? .elbowCreases : .arms, rect: CGRect(x: 26, y: 128, width: 28, height: 22), corner: 8),
            Part(area: side == .front ? .elbowCreases : .arms, rect: CGRect(x: 146, y: 128, width: 28, height: 22), corner: 8),
            Part(area: .arms, rect: CGRect(x: 22, y: 152, width: 26, height: 40)),
            Part(area: .arms, rect: CGRect(x: 152, y: 152, width: 26, height: 40)),
            Part(area: .hands, rect: CGRect(x: 18, y: 194, width: 28, height: 28), corner: 14),
            Part(area: .hands, rect: CGRect(x: 154, y: 194, width: 28, height: 28), corner: 14),
            Part(area: .diaperArea, rect: CGRect(x: 62, y: 180, width: 76, height: 36), corner: 12),
            Part(area: .legs, rect: CGRect(x: 64, y: 218, width: 32, height: 46)),
            Part(area: .legs, rect: CGRect(x: 104, y: 218, width: 32, height: 46)),
            Part(area: side == .back ? .kneeCreases : .legs, rect: CGRect(x: 64, y: 266, width: 32, height: 20), corner: 8),
            Part(area: side == .back ? .kneeCreases : .legs, rect: CGRect(x: 104, y: 266, width: 32, height: 20), corner: 8),
            Part(area: .legs, rect: CGRect(x: 66, y: 288, width: 28, height: 42)),
            Part(area: .legs, rect: CGRect(x: 106, y: 288, width: 28, height: 42)),
            Part(area: .feet, rect: CGRect(x: 58, y: 332, width: 38, height: 22), corner: 11),
            Part(area: .feet, rect: CGRect(x: 104, y: 332, width: 38, height: 22), corner: 11),
        ]
        return [head] + common
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(parts) { part in
                let isOn = selected.contains(part.area)
                RoundedRectangle(cornerRadius: part.corner)
                    .fill(isOn ? palette.indigo : palette.paper)
                    .overlay(RoundedRectangle(cornerRadius: part.corner).strokeBorder(isOn ? palette.indigo : palette.graphite, lineWidth: 1))
                    .frame(width: part.rect.width, height: part.rect.height)
                    .contentShape(Rectangle())
                    .onTapGesture { toggle(part.area) }
                    .offset(x: part.rect.minX, y: part.rect.minY)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 200, height: 360, alignment: .topLeading)
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(side == .front ? "Body outline, front" : "Body outline, back")
        .accessibilityValue(BodyArea.allCases.filter(selected.contains).map(\.words).joined(separator: ", "))
        .accessibilityActions {
            ForEach(areas, id: \.self) { area in
                Button(selected.contains(area) ? "Remove \(area.words)" : "Add \(area.words)") { toggle(area) }
            }
        }
    }

    /// The areas this side shows, once each.
    private var areas: [BodyArea] {
        let shown = Set(parts.map(\.area))
        return BodyArea.allCases.filter(shown.contains)
    }

    private func toggle(_ area: BodyArea) {
        if selected.contains(area) { selected.remove(area) } else { selected.insert(area) }
    }
}
