import Foundation
import Kanna

/// HTML로 그려 주는 게시판을 선택자로 읽는다.
struct HTMLAdapter: BoardAdapter {
    func list(_ board: Board, page: Int, keyword: String?, context: AdapterContext) async throws -> [NoticeItem] {
        let url = try board.listURL(page: page, keyword: keyword)
        let (html, finalURL) = try await context.fetcher.string(from: url, encoding: board.encoding)
        return try HTMLBoardParser.list(html: html, baseURL: finalURL, board: board, selectors: context.selectors)
    }

    func detail(_ board: Board, url: URL, context: AdapterContext) async throws -> NoticeDetail {
        let (html, finalURL) = try await context.fetcher.string(from: url, encoding: board.encoding)
        return try HTMLBoardParser.detail(html: html, url: finalURL, board: board, selectors: context.selectors)
    }
}

/// 네트워크 없이 HTML 문자열만으로 목록·상세를 뽑는다. 테스트에서도 쓴다.
public enum HTMLBoardParser {
    public static func list(html: String, baseURL: URL, board: Board, selectors: Board.Selectors) throws -> [NoticeItem] {
        guard let rowSelector = selectors.row, let titleSelector = selectors.title else {
            throw NoticeError.decoding("\(board.id): 목록 선택자(row, title)가 없음")
        }
        let document = try HTML(html: html, encoding: .utf8)
        let attribute = selectors.linkAttribute ?? "href"
        var seen = Set<URL>()
        var items: [NoticeItem] = []

        for row in select(document, rowSelector) {
            guard let titleNode = select(row, titleSelector).first else { continue }
            let title = clean(titleNode.text)
            guard !title.isEmpty else { continue }

            let linkNode = selectors.link.flatMap { select(row, $0).first } ?? titleNode
            guard let raw = linkNode[attribute] ?? titleNode[attribute] ?? row[attribute],
                  let url = resolve(raw, rule: board.link, baseURL: baseURL),
                  !seen.contains(url) else {
                continue
            }
            seen.insert(url)

            let dateNode = selectors.date.flatMap { select(row, $0).first?.text }
            // 날짜 칸을 따로 짚은 경우에만 연도 없는 "08-27"을 날짜로 본다. 행 전체에서는 시각과 헷갈린다.
            let date: String? = NoticeDate.normalize(dateNode, allowMonthDay: true) ?? NoticeDate.normalize(row.text)
            let isPinned = selectors.pinned.map { !select(row, $0).isEmpty } ?? false
            let hasAttachment = selectors.attachmentMark.map { !select(row, $0).isEmpty } ?? false
            let author = selectors.author.flatMap { select(row, $0).first?.text }.map(clean)

            items.append(NoticeItem(title: title, url: url, date: date,
                                    isPinned: isPinned, hasAttachment: hasAttachment,
                                    author: author?.isEmpty == false ? author : nil))
        }
        return items
    }

    public static func detail(html: String, url: URL, board: Board, selectors: Board.Selectors) throws -> NoticeDetail {
        let document = try HTML(html: html, encoding: .utf8)
        guard let bodySelector = selectors.detailBody, let body = select(document, bodySelector).first else {
            throw NoticeError.noContent("본문을 찾지 못함: \(url.absoluteString)")
        }
        let title = selectors.detailTitle.flatMap { select(document, $0).first?.text }.map(clean)
        let date = selectors.detailDate.flatMap { select(document, $0).first?.text }.flatMap { NoticeDate.normalize($0) }

        var attachments: [NoticeAttachment] = []
        if let attachmentSelector = selectors.attachment {
            for node in select(document, attachmentSelector) {
                guard let href = node["href"], let fileURL = resolve(href, rule: board.attachmentLink, baseURL: url) else { continue }
                // 이름 뒤에 붙은 용량 표기 "(139.7 KB)"는 저장할 파일 이름에 넣지 않는다.
                let name = clean(node.text).replacingOccurrences(of: #"\s*\([\d.,]+\s*[KMG]?B\)$"#, with: "",
                                                                  options: [.regularExpression, .caseInsensitive])
                attachments.append(NoticeAttachment(name: name.isEmpty ? fileURL.lastPathComponent : name, url: fileURL))
            }
        }

        return NoticeDetail(url: url, title: title, date: date,
                            bodyHTML: body.innerHTML ?? body.toHTML ?? "", attachments: attachments)
    }

    /// `xpath:`로 시작하면 XPath로, 아니면 CSS 선택자로 고른다.
    static func select(_ node: Kanna.Searchable, _ selector: String) -> [Kanna.XMLElement] {
        if selector.hasPrefix("xpath:") {
            return Array(node.xpath(String(selector.dropFirst("xpath:".count))))
        }
        return Array(node.css(selector))
    }

    static func resolve(_ raw: String, rule: Board.LinkRule?, baseURL: URL) -> URL? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let rule {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern),
                  let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) else {
                return nil
            }
            var filled = rule.template
            for index in stride(from: match.numberOfRanges - 1, through: 1, by: -1) {
                guard let range = Range(match.range(at: index), in: value) else { continue }
                filled = filled.replacingOccurrences(of: "$\(index)", with: String(value[range]))
            }
            value = filled
        }
        guard !value.isEmpty, !value.hasPrefix("javascript:"), !value.hasPrefix("#") else { return nil }
        value = value.replacingOccurrences(of: "&amp;", with: "&")
        return URL(string: value, encodingInvalidCharacters: true).flatMap {
            $0.scheme == nil ? URL(string: value, relativeTo: baseURL)?.absoluteURL : $0
        } ?? URL(string: value.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "", relativeTo: baseURL)?.absoluteURL
    }

    static func clean(_ text: String?) -> String {
        (text ?? "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
