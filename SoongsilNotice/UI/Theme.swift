//
//  Theme.swift
//  Notissu
//
//  Copyright © 2026 Notissu. All rights reserved.
//

import SwiftUI
import NoticeKit

/// 2.x의 숭실 보라를 이어 쓴다. 채움에는 `#816DEC`, 작은 글자에는 대비가 충분한 `#5D4DE8`.
enum Theme {
    static let accent = Color(light: 0x816DEC, dark: 0x9A8AF0)
    static let accentText = Color(light: 0x5D4DE8, dark: 0xB2A4EF)
    static let accentBackground = Color(light: 0xEBE6FB, dark: 0x2A2547)
    static let ink = Color(light: 0x121417, dark: 0xF2F3F5)
    static let secondary = Color(light: 0x5E646E, dark: 0x9EA4AD)
    static let readTitle = Color(light: 0x3A3F47, dark: 0xC9CDD3)
    static let separator = Color(light: 0xE4E6EA, dark: 0x2C2F35)
    static let groupedBackground = Color(light: 0xF4F5F7, dark: 0x1C1E22)
    static let railBackground = Color(light: 0xF7F8FA, dark: 0x16181B)
    static let background = Color(light: 0xFFFFFF, dark: 0x0E0F11)

    static let railWidth: CGFloat = 56
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: 1)
        })
    }
}

/// 목록 칸과 본문 칸으로 나뉜 넓은 배치인지.
private struct SplitLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isSplitLayout: Bool {
        get { self[SplitLayoutKey.self] }
        set { self[SplitLayoutKey.self] = newValue }
    }
}

enum NoticeFormat {
    private static let seoul = TimeZone(identifier: "Asia/Seoul")!

    /// 목록용 짧은 날짜. 오늘·어제, 올해는 "10. 26.", 그 전은 "2025. 12. 3."
    static func shortDate(_ ymd: String?, today: Date = Date()) -> String {
        guard let ymd, let date = parse(ymd) else { return "" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = seoul
        if calendar.isDate(date, inSameDayAs: today) { return "오늘" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), calendar.isDate(date, inSameDayAs: yesterday) {
            return "어제"
        }
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let thisYear = calendar.component(.year, from: today)
        if c.year == thisYear { return "\(c.month ?? 0). \(c.day ?? 0)." }
        return "\(c.year ?? 0). \(c.month ?? 0). \(c.day ?? 0)."
    }

    /// 본문 머리말용 날짜. "2026. 10. 29."
    static func fullDate(_ ymd: String?) -> String {
        guard let ymd else { return "" }
        let parts = ymd.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return ymd }
        return "\(parts[0]). \(parts[1]). \(parts[2])."
    }

    /// "마감 D-8", "오늘 마감". 지난 마감은 보이지 않는다.
    static func deadline(_ item: NoticeItem, today: Date = Date()) -> String? {
        guard let deadline = item.deadline else { return nil }
        let left = deadline.daysLeft(from: today)
        if left < 0 { return nil }
        return left == 0 ? "오늘 마감" : "마감 D-\(left)"
    }

    private static func parse(_ ymd: String) -> Date? {
        let parts = ymd.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = seoul
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
