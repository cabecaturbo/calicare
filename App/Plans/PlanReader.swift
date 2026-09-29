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
                    duration: item.duration, sourcePage: item.source_page, sourceLine: item.source_line
                )
            }
        } catch let FunctionsError.httpError(code, _) where code == 401 {
            throw Failure.notSignedIn
        } catch let FunctionsError.httpError(code, _) where code == 429 {
            throw Failure.tooMany
        }
    }
}
