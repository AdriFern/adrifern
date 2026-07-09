import Foundation

/// Voluntary WhatsApp notifications via wa.me click-to-chat links.
/// iOS forbids sending messages on the user's behalf, so every link
/// opens WhatsApp with the text prefilled and the user taps send —
/// consent stays with the sender, delivery stays with WhatsApp.
enum WhatsAppLink {
    /// With a number the co-parent's chat opens directly; without one
    /// WhatsApp shows its recipient picker.
    static func url(number: String, text: String) -> URL? {
        let digits = number.filter(\.isWholeNumber)
        var components = URLComponents()
        components.scheme = "https"
        components.host = "wa.me"
        components.path = digits.isEmpty ? "/" : "/\(digits)"
        components.queryItems = [URLQueryItem(name: "text", value: text)]
        return components.url
    }

    static func requestMessage(memberName: String, changes: [DayChange], isPattern: Bool) -> String {
        let count = changes.count
        if isPattern {
            return String(localized: "I've sent you a repeating-schedule proposal for \(memberName) in Nido, covering \(count) days. Open Nido to approve or decline it. 🪺")
        }
        if count == 1, let only = changes.first {
            return String(localized: "I've proposed a change for \(memberName) in Nido: \(Day.shortLabel(for: only.dateKey)). Open Nido to approve or decline it. 🪺")
        }
        return String(localized: "I've proposed changes to \(count) of \(memberName)'s days in Nido. Open Nido to review them. 🪺")
    }

    static func inviteMessage(url: URL) -> String {
        String(localized: "Join our custody calendar on Nido: \(url.absoluteString)")
    }
}
