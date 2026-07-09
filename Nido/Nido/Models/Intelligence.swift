import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device AI via Apple's Foundation Models framework (iOS 26+,
/// Apple Intelligence devices). Custody data never leaves the iPhone:
/// the model runs locally, offline, at no cost.
///
/// Everything here is optional sugar. The app compiles without the
/// framework (older Xcode/SDK) and runs without the model (older
/// devices, Apple Intelligence disabled) — callers check `isAvailable`
/// and every feature has a deterministic fallback.
enum NidoIntelligence {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    /// Rewrites a proposal message in a calmer, cooperative tone,
    /// keeping facts and language unchanged. Nil when unavailable.
    static func neutralTone(for message: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let session = LanguageModelSession(instructions: """
                You help separated parents communicate about custody scheduling. \
                Rewrite the user's message so it is calm, neutral, brief and cooperative. \
                Keep every fact (dates, names, times) unchanged. \
                Answer in the same language as the message. \
                Return only the rewritten message, nothing else.
                """)
            let reply = try? await session.respond(to: message).content
            let trimmed = reply?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
        #endif
        return nil
    }

    /// Turns precomputed month facts into one warm, factual paragraph.
    /// Nil when unavailable — callers then show the facts themselves.
    static func monthlySummary(facts: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let session = LanguageModelSession(instructions: """
                You summarize custody-calendar statistics for a co-parenting app. \
                Write one warm, strictly factual paragraph of two or three sentences \
                in the same language as the facts. Use only the numbers given — \
                never invent or extrapolate. No lists, no headings, no advice.
                """)
            let reply = try? await session.respond(to: facts).content
            let trimmed = reply?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
        #endif
        return nil
    }

    /// One requested day: a date plus which side it should go to.
    struct DraftedDay: Sendable {
        var dateKey: String
        var withMe: Bool
    }

    /// Converts a natural-language ask ("I need the second weekend of
    /// August") into concrete calendar days. Returns validated, deduped,
    /// today-or-later date keys — or nil when the model is unavailable
    /// or produced nothing usable. The caller previews the days and the
    /// existing approval rules apply unchanged; the AI never sends.
    static func draftProposalDays(from text: String) async -> [DraftedDay]? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let today = Day.todayKey
            let session = LanguageModelSession(instructions: """
                You convert a parent's natural-language request about custody days \
                into concrete calendar dates. Today is \(today); resolve relative \
                expressions like "next weekend" against it. A weekend is Saturday \
                and Sunday. Only include days from today up to one year ahead. \
                Days the parent asks to have are "with me"; days they offer to \
                the other parent are not.
                """)
            guard let draft = try? await session.respond(
                to: text,
                generating: GeneratedProposal.self
            ).content else { return nil }
            let today_ = today
            var seen = Set<String>()
            let valid = draft.days
                .filter { Day.date(from: $0.dateKey) != nil && $0.dateKey >= today_ }
                .filter { seen.insert($0.dateKey).inserted }
                .sorted { $0.dateKey < $1.dateKey }
                .prefix(60)
                .map { DraftedDay(dateKey: $0.dateKey, withMe: $0.withMe) }
            return valid.isEmpty ? nil : Array(valid)
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
private struct GeneratedDay {
    @Guide(description: "Calendar day, formatted exactly yyyy-MM-dd")
    var dateKey: String
    @Guide(description: "true when this day should be with the parent who is asking; false when they are offering it to the other parent")
    var withMe: Bool
}

@available(iOS 26.0, *)
@Generable
private struct GeneratedProposal {
    @Guide(description: "Every calendar day the request refers to, expanded (a weekend is its Saturday and Sunday)")
    var days: [GeneratedDay]
}
#endif
