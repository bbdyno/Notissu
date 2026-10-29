import Foundation

/// 공지 제목에 적힌 마감일.
///
/// 틀리게 잡는 것보다 놓치는 쪽이 낫다고 보고, 다음 경우만 마감으로 읽는다.
/// - 물결표 바로 뒤의 날짜: `(~11/6금 15시)`, `(~12/21까지)`
/// - 기간의 끝: `(10.6~19까지)`
/// - "까지"나 "마감"이 뒤따르는 날짜: `(11/12 오후 2시까지)`, `(2026.09.16.(수) 18:00 까지)`, `10.16(금) 16:00 마감`
/// 행사 날짜처럼 그냥 적힌 날짜는 마감으로 보지 않는다.
public struct NoticeDeadline: Sendable, Hashable {
    public let year: Int
    public let month: Int
    public let day: Int

    private static let seoul = TimeZone(identifier: "Asia/Seoul")!

    /// 오늘부터 마감일까지 남은 날. 오늘이 마감이면 0, 지났으면 음수.
    public func daysLeft(from today: Date = Date()) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.seoul
        guard let due = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return 0 }
        let start = calendar.startOfDay(for: today)
        return calendar.dateComponents([.day], from: start, to: due).day ?? 0
    }

    /// `postedOn`은 `yyyy-MM-dd`. 연도가 없는 마감일은 게시일 뒤로 가장 가까운 날로 본다.
    public static func find(in title: String, postedOn: String?) -> NoticeDeadline? {
        let posted = postedOn.flatMap(parse(ymd:)) ?? today()
        for rule in rules {
            guard let match = rule.regex.lastMatch(in: title) else { continue }
            let numbers = (1..<match.numberOfRanges).compactMap { index -> Int? in
                Range(match.range(at: index), in: title).flatMap { Int(title[$0]) }
            }
            guard let found = rule.read(numbers, posted) else { continue }
            return found
        }
        return nil
    }

    private struct Rule: Sendable {
        let regex: NSRegularExpression
        let read: @Sendable ([Int], (year: Int, month: Int, day: Int)) -> NoticeDeadline?
    }

    // 날짜 뒤에 요일·시각 정도만 끼어 있고 "까지|마감"으로 끝나는 꼴.
    private static let tail = #"[^/~\n]{0,20}?(?:까지|마감)"#

    private static let rules: [Rule] = [
        // 2026.09.16.(수) 18:00 까지
        Rule(regex: regex(#"(20\d{2})\s*[./]\s*(\d{1,2})\s*[./]\s*(\d{1,2})\.?"# + tail)) { n, _ in
            make(n[0], n[1], n[2])
        },
        // 10.6~19까지 (기간의 끝, 같은 달)
        Rule(regex: regex(#"(?<![\d.])(\d{1,2})\s*[./]\s*(\d{1,2})\s*~\s*(\d{1,2})(?![\d./])"#)) { n, posted in
            nearest(month: n[0], day: n[2], after: posted)
        },
        // ~11/6, ~ 12/21까지
        Rule(regex: regex(#"~\s*(\d{1,2})\s*[./]\s*(\d{1,2})(?![\d])"#)) { n, posted in
            nearest(month: n[0], day: n[1], after: posted)
        },
        // 11/12 오후 2시까지, 10.16(금) 16:00 마감
        Rule(regex: regex(#"(?<![\d.])(\d{1,2})\s*[./]\s*(\d{1,2})(?![\d])"# + tail)) { n, posted in
            nearest(month: n[0], day: n[1], after: posted)
        },
        // 11월 6일(금)까지
        Rule(regex: regex(#"(\d{1,2})\s*월\s*(\d{1,2})\s*일"# + tail)) { n, posted in
            nearest(month: n[0], day: n[1], after: posted)
        },
    ]

    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern)
    }

    private static func make(_ year: Int, _ month: Int, _ day: Int) -> NoticeDeadline? {
        guard (2000...2100).contains(year), (1...12).contains(month), (1...31).contains(day) else { return nil }
        return NoticeDeadline(year: year, month: month, day: day)
    }

    /// 게시일과 같은 해로 보되, 게시일보다 두 달 넘게 앞이면 다음 해로 넘긴다. 12월 글의 "~1/5" 같은 경우.
    private static func nearest(month: Int, day: Int, after posted: (year: Int, month: Int, day: Int)) -> NoticeDeadline? {
        let year = month < posted.month - 2 ? posted.year + 1 : posted.year
        return make(year, month, day)
    }

    private static func parse(ymd: String) -> (year: Int, month: Int, day: Int)? {
        let parts = ymd.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return (parts[0], parts[1], parts[2])
    }

    private static func today() -> (year: Int, month: Int, day: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = seoul
        let c = calendar.dateComponents([.year, .month, .day], from: Date())
        return (c.year ?? 2026, c.month ?? 1, c.day ?? 1)
    }
}

public extension NoticeItem {
    var deadline: NoticeDeadline? {
        NoticeDeadline.find(in: title, postedOn: date)
    }
}

private extension NSRegularExpression {
    /// 제목 끝쪽 괄호에 마감이 붙는 경우가 많아 마지막으로 맞는 곳을 쓴다.
    func lastMatch(in text: String) -> NSTextCheckingResult? {
        matches(in: text, range: NSRange(text.startIndex..., in: text)).last
    }
}
