import Core
import Foundation
import Supabase

/// Sends a plan's text (never the file) to the parse-care-plan function and
/// turns the checked items into drafts for review. See
/// supabase/functions/parse-care-plan.
enum PlanReader {
    enum Failure: Error {
        case notSignedIn
        case tooMany
        case unavailable
    }

    private struct Request: Encodable {
        let text: String
    }

    private struct Response: Decodable {
        struct Item: Decodable {
            let kind: String
            let text: String
            let dose: String?
            let frequency: String?
            let timing: String?
            let duration: String?
            let source_page: Int
            let source_line: String
            let label: String?
            let detail: String?
            let category: String?
            let plain: String?
        }

        let items: [Item]
    }

    static func read(_ text: String, client: SupabaseClient? = Backend.client) async throws -> [PlanItemDraft] {
        guard let client else { throw Failure.unavailable }
        guard client.auth.currentSession != nil else { throw Failure.notSignedIn }
        do {
            let response: Response = try await client.functions.invoke(
                "parse-care-plan",
                options: FunctionInvokeOptions(method: .post, body: Request(text: text))
            )
            return response.items.compactMap { item in
                guard let kind = PlanItemKind(rawValue: item.kind) else { return nil }
                return PlanItemDraft(
                    kind: kind, text: item.text, dose: item.dose, frequency: item.frequency, timing: item.timing,
                    duration: item.duration, sourcePage: item.source_page, sourceLine: item.source_line,
                    label: item.label, detail: item.detail, category: item.category.flatMap(StepCategory.init),
                    plain: item.plain
                )
            }
        } catch let FunctionsError.httpError(code, _) where code == 401 {
            throw Failure.notSignedIn
        } catch let FunctionsError.httpError(code, _) where code == 429 {
            throw Failure.tooMany
        }
    }

    private struct PlainRequest: Encodable {
        struct Line: Encodable { let id: String; let text: String }
        let mode = "plain"
        let lines: [Line]
    }

    private struct PlainResponse: Decodable {
        struct Item: Decodable { let id: String; let plain: String }
        let items: [Item]
    }

    /// Plain words for the provider's lines, by item id. Only the words are
    /// sent; nothing is kept on the server.
    static func plainWords(_ lines: [(id: UUID, text: String)], client: SupabaseClient? = Backend.client) async throws -> [UUID: String] {
        guard let client else { throw Failure.unavailable }
        guard client.auth.currentSession != nil else { throw Failure.notSignedIn }
        let request = PlainRequest(lines: lines.map { .init(id: $0.id.uuidString, text: $0.text) })
        let response: PlainResponse = try await client.functions.invoke(
            "parse-care-plan", options: FunctionInvokeOptions(method: .post, body: request)
        )
        return Dictionary(response.items.compactMap { item in UUID(uuidString: item.id).map { ($0, item.plain) } },
                          uniquingKeysWith: { a, _ in a })
    }
}
