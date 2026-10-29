import Foundation

public struct NoticeItem: Codable, Sendable, Hashable, Identifiable {
    public var id: String { url.absoluteString }
    public let title: String
    public let url: URL
    /// `yyyy-MM-dd` 형태로 맞춘 날짜. 게시판에 날짜가 없으면 `nil`.
    public let date: String?
    public let isPinned: Bool
    public let hasAttachment: Bool
    public let author: String?

    public init(title: String, url: URL, date: String?, isPinned: Bool = false,
                hasAttachment: Bool = false, author: String? = nil) {
        self.title = title
        self.url = url
        self.date = date
        self.isPinned = isPinned
        self.hasAttachment = hasAttachment
        self.author = author
    }
}

public struct NoticeAttachment: Codable, Sendable, Hashable {
    public let name: String
    public let url: URL

    public init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

public struct NoticeDetail: Codable, Sendable, Hashable {
    public let url: URL
    public let title: String?
    public let date: String?
    /// 게시판 본문 영역의 HTML. 화면에 넣기 전에 스타일을 씌운다.
    public let bodyHTML: String
    public let attachments: [NoticeAttachment]

    public init(url: URL, title: String?, date: String?, bodyHTML: String, attachments: [NoticeAttachment]) {
        self.url = url
        self.title = title
        self.date = date
        self.bodyHTML = bodyHTML
        self.attachments = attachments
    }

    /// 태그를 걷어 낸 본문 글자. 점검 도구가 본문이 비었는지 볼 때 쓴다.
    public var bodyText: String {
        bodyHTML
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum NoticeError: Error, Sendable, Equatable {
    case invalidURL(String)
    case http(status: Int, url: String)
    case decoding(String)
    case unsupported(String)
    case noContent(String)
}
