import Foundation

/// 게시판마다 다른 날짜 표기를 `yyyy-MM-dd`로 맞춘다.
public enum NoticeDate {
    private static let fullPattern = try! NSRegularExpression(
        pattern: #"(20\d{2}|\d{2})\s*[.\-/년]\s*(\d{1,2})\s*[.\-/월]\s*(\d{1,2})"#)

    private static let monthDayPattern = try! NSRegularExpression(
        pattern: #"^\s*(\d{1,2})\s*[.\-/]\s*(\d{1,2})\s*\.?\s*$"#)

    /// 글 안에서 처음 나오는 날짜를 찾는다. 연도가 두 자리면 2000년대로 본다.
    ///
    /// `allowMonthDay`이면 연도 없이 "08-27"만 있는 칸도 받아 올해 날짜로 채운다.
    /// 그 날짜가 오늘보다 뒤면 작년 글로 본다.
    public static func normalize(_ text: String?, allowMonthDay: Bool = false, today: Date = Date()) -> String? {
        guard let text, !text.isEmpty else { return nil }
        if let full = fullDate(in: text) {
            return full
        }
        guard allowMonthDay,
              let match = monthDayPattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let m = Range(match.range(at: 1), in: text), let d = Range(match.range(at: 2), in: text),
              let month = Int(text[m]), let day = Int(text[d]),
              (1...12).contains(month), (1...31).contains(day) else {
            return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = calendar.dateComponents([.year, .month, .day], from: today)
        guard let thisYear = now.year else { return nil }
        let isFuture = (month, day) > (now.month ?? 12, now.day ?? 31)
        return String(format: "%04d-%02d-%02d", isFuture ? thisYear - 1 : thisYear, month, day)
    }

    private static func fullDate(in text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        for match in fullPattern.matches(in: text, range: range) {
            guard let y = Range(match.range(at: 1), in: text),
                  let m = Range(match.range(at: 2), in: text),
                  let d = Range(match.range(at: 3), in: text),
                  var year = Int(text[y]), let month = Int(text[m]), let day = Int(text[d]) else {
                continue
            }
            if year < 100 { year += 2000 }
            guard (2000...2100).contains(year), (1...12).contains(month), (1...31).contains(day) else { continue }
            return String(format: "%04d-%02d-%02d", year, month, day)
        }
        return nil
    }

    /// 밀리초 또는 초 단위 유닉스 시각.
    public static func normalize(epoch value: Double) -> String {
        let seconds = value > 10_000_000_000 ? value / 1000 : value
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date(timeIntervalSince1970: seconds))
    }
}
