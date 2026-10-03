import Core
import Foundation
import Testing

/// Every app-written string reads at grade 6 or easier. Provider and parent
/// words are never scored: they're shown exactly as written.
struct ReadingGradeTests {
    /// Calls whose first string literal is shown to the parent.
    static let displayCalls = ["Text", "Button", "Label", "navigationTitle", "alert", "confirmationDialog",
                               "FormHeader", "SettingsLabel", "LabeledContent", "Toggle", "TextField", "Section"]

    /// App-written strings in the app's source (debug-only screens left out).
    static func appStrings() throws -> [(file: String, text: String)] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let app = root.appendingPathComponent("App")
        let files = FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil)!
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" && !$0.path.contains("/Debug/") }
        var found: [(String, String)] = []
        for file in files {
            let source = Array(try String(contentsOf: file, encoding: .utf8))
            for call in displayCalls {
                let opener = Array(call + "(\"")
                var i = 0
                while i + opener.count <= source.count {
                    guard Array(source[i..<(i + opener.count)]) == opener,
                          i == 0 || !(source[i - 1].isLetter || source[i - 1].isNumber) else { i += 1; continue }
                    if let (text, end) = literal(source, from: i + opener.count) {
                        if text.contains(where: \.isLetter) { found.append((file.lastPathComponent, text)) }
                        i = end
                    } else {
                        i += 1
                    }
                }
            }
        }
        return found
    }

    /// Reads a string literal starting after its opening quote. Interpolations,
    /// nested parentheses and quotes included, become the word "it".
    static func literal(_ chars: [Character], from start: Int) -> (String, Int)? {
        var text = ""
        var i = start
        while i < chars.count {
            let c = chars[i]
            if c == "\"" { return (text, i + 1) }
            if c == "\\", i + 1 < chars.count {
                if chars[i + 1] == "(" {
                    var depth = 1
                    i += 2
                    while i < chars.count, depth > 0 {
                        if chars[i] == "(" { depth += 1 } else if chars[i] == ")" { depth -= 1 }
                        i += 1
                    }
                    text += "it"
                    continue
                }
                i += 2
                continue
            }
            if c == "\n" { return nil }
            text.append(c)
            i += 1
        }
        return nil
    }

    @Test func appStringsReadAtGradeSix() throws {
        let strings = try Self.appStrings()
        #expect(strings.count > 200, "found \(strings.count) strings; the scan may be broken")
        let hard = strings.filter { !ReadingGrade.isEasy($0.text) }
        for (file, text) in hard {
            Issue.record("\(file): \"\(text)\" grade \(String(format: "%.1f", ReadingGrade.grade(text)))")
        }
    }

    @Test func remindersAndToDoReadAtGradeSix() {
        var strings: [String] = []
        for kind in ReminderKind.allCases {
            strings += [ReminderCopy.title(kind, childName: "Cal"), ReminderCopy.title(kind, childName: "Cal", things: 5),
                        ReminderCopy.body(kind, childName: "Cal"), ReminderCopy.settingsTitle(kind)]
        }
        strings += ReminderAction.allCases.map(\.title)
        strings += TodoBlock.allCases.map(\.title) + ["Do skin care", "2 of 3-4 today", "Done today", "3 of 5 done"]
        for text in strings where !ReadingGrade.isEasy(text) {
            Issue.record("\"\(text)\" grade \(String(format: "%.1f", ReadingGrade.grade(text)))")
        }
    }

    @Test func generatedLabelsReadAtGradeSix() {
        let lines = LegacyPlanFixture.items.map(\.text) + LegacyPlanFixture.steps.map(\.name)
        // Only the app's own words in a label are scored; names copied from the plan aren't.
        for line in lines {
            guard let label = StepLabeler.wording(for: line).label else { continue }
            let mine = Self.appWords(label, line)
            #expect(ReadingGrade.isEasy(mine), "label \"\(label)\": \"\(mine)\"")
        }
        for item in LegacyPlanFixture.items where item.kind == .supplement && !SupplementDisplay.isMention(item.text) {
            let info = PlanItemInfo(id: UUID(), planID: UUID(), kind: .supplement, text: item.text, dose: item.dose,
                                    frequency: item.frequency, timing: nil, duration: nil, sourcePage: 1, sourceLine: item.sourceLine,
                                    isConfirmed: true, order: 0)
            let label = "Give \(SupplementDisplay(info).name)"
            #expect(ReadingGrade.isEasy(Self.appWords(label, item.text)), "\(label)")
        }
    }

    /// The label's words that aren't copied from the plan's line.
    static func appWords(_ label: String, _ line: String) -> String {
        let theirs = productWords(line)
        return label.split(separator: " ").filter { !theirs.contains($0.lowercased().filter(\.isLetter)) }.joined(separator: " ")
    }

    /// Words copied from the plan (product names) aren't the app's words.
    static func productWords(_ line: String) -> Set<String> {
        Set(line.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
    }

    @Test func gradeMath() {
        #expect(ReadingGrade.syllables(in: "cat") == 1)
        #expect(ReadingGrade.syllables(in: "water") == 2)
        #expect(ReadingGrade.syllables(in: "moisturizer") == 4)
        #expect(ReadingGrade.grade("The cat sat on the mat. It was warm.") < 2)
        #expect(ReadingGrade.grade("Implementation necessitates comprehensive interdisciplinary coordination.") > 12)
        #expect(ReadingGrade.isEasy("Supplements"))
        #expect(!ReadingGrade.isEasy("Interdisciplinary"))
    }
}
