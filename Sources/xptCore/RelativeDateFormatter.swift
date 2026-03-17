import Foundation

struct RelativeDateFormatter {
    let now: Date

    init(now: Date = Date()) {
        self.now = now
    }

    func string(from date: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        switch seconds {
        case ..<60:
            return "just now"
        case 60..<3600:
            let m = seconds / 60
            return "\(m) minute\(m == 1 ? "" : "s") ago"
        case 3600..<86400:
            let h = seconds / 3600
            return "\(h) hour\(h == 1 ? "" : "s") ago"
        case 86400..<172800:
            return "yesterday"
        default:
            let d = seconds / 86400
            return "\(d) days ago"
        }
    }
}
