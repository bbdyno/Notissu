import Foundation

/// 글로벌미디어·디지털미디어 (`{api}/v1/board/?page=&size=&menuId=`).
///
/// 목록 응답에 본문이 같이 오지만 첨부 목록이 비어 있어서 상세는 `{api}/v1/board/{id}`를 다시 부른다.
/// 본문은 Lexical 편집기 상태(JSON)라 HTML로 바꿔 준다. 첨부는 파일 번호만 오므로
/// 사이트와 같이 `PATCH {api}/v1/file/{fileId}`로 이름과 주소를 받는다.
///
/// 설정: `list`/`search`는 `{api}`와 `{page0}`을 쓰고, `options.api`(API 주소), `options.view`(상세 화면 틀).
/// 상세·첨부 틀은 `options.detail`, `options.file`로 덮어쓸 수 있다.
struct NextApiV1Adapter: BoardAdapter {
    func list(_ board: Board, page: Int, keyword: String?, context: AdapterContext) async throws -> [NoticeItem] {
        let url = try board.apiListURL(page: page, keyword: keyword)
        let response = try await context.fetcher.decode(NextApiV1Parser.ListResponse.self, from: url)
        return try NextApiV1Parser.list(response, board: board)
    }

    func detail(_ board: Board, url: URL, context: AdapterContext) async throws -> NoticeDetail {
        let id = try board.itemID(from: url)
        let apiURL = try board.apiURL(option: "detail", default: "{api}/v1/board/{id}", values: ["id": id])
        let response = try await context.fetcher.decode(NextApiV1Parser.DetailResponse.self, from: apiURL)
        let post = try NextApiV1Parser.post(response, url: apiURL)

        var attachments: [NoticeAttachment] = []
        for fileID in post.attachments ?? [] {
            let fileURL = try board.apiURL(option: "file", default: "{api}/v1/file/{id}", values: ["id": String(fileID.fileId)])
            // 첨부 하나를 못 읽어도 본문은 보여 준다.
            guard let info = try? await context.fetcher.decode(NextApiV1Parser.FileResponse.self, from: fileURL, method: "PATCH"),
                  let attachment = NextApiV1Parser.attachment(info) else { continue }
            attachments.append(attachment)
        }
        return try NextApiV1Parser.detail(post, url: url, attachments: attachments)
    }
}

enum NextApiV1Parser {
    struct ListResponse: Decodable {
        struct Page: Decodable {
            let boards: [Post]
        }
        let success: Bool?
        let message: String?
        let data: Page?
    }

    struct DetailResponse: Decodable {
        let success: Bool?
        let message: String?
        let data: Post?
    }

    struct Post: Decodable {
        struct FileRef: Decodable {
            let fileId: Int
        }
        let id: Int
        let title: String
        let isPinned: Bool?
        let hasAttachment: Bool?
        let content: String?
        let userName: String?
        let createdAt: String?
        let attachments: [FileRef]?
    }

    struct FileResponse: Decodable {
        struct File: Decodable {
            let url: String
            let name: String?
            let `extension`: String?
        }
        let data: File?
    }

    static func list(_ response: ListResponse, board: Board) throws -> [NoticeItem] {
        guard let posts = response.data?.boards else {
            throw NoticeError.decoding("\(board.id): 목록 응답에 data.boards 없음 (\(response.message ?? "-"))")
        }
        return try posts.map { post in
            NoticeItem(title: HTMLBoardParser.clean(post.title),
                       url: try board.viewURL(id: String(post.id)),
                       // 사이트는 `createdAt`을 시간대 변환 없이 그대로 보여 준다.
                       date: NoticeDate.normalize(post.createdAt),
                       isPinned: post.isPinned ?? false,
                       hasAttachment: post.hasAttachment ?? false,
                       author: post.userName)
        }
    }

    static func post(_ response: DetailResponse, url: URL) throws -> Post {
        guard let post = response.data else {
            throw NoticeError.noContent("상세 응답에 data 없음 (\(response.message ?? "-")): \(url.absoluteString)")
        }
        return post
    }

    static func detail(_ post: Post, url: URL, attachments: [NoticeAttachment]) throws -> NoticeDetail {
        NoticeDetail(url: url,
                     title: HTMLBoardParser.clean(post.title),
                     date: NoticeDate.normalize(post.createdAt),
                     bodyHTML: try LexicalHTML.render(post.content ?? ""),
                     attachments: attachments)
    }

    static func attachment(_ response: FileResponse) -> NoticeAttachment? {
        guard let file = response.data, let url = URL(string: file.url, encodingInvalidCharacters: true) else { return nil }
        var name = HTMLBoardParser.clean(file.name)
        if name.isEmpty {
            name = url.lastPathComponent
        } else if let ext = file.extension, !ext.isEmpty, !name.lowercased().hasSuffix(".\(ext.lowercased())") {
            name += ".\(ext)"
        }
        return NoticeAttachment(name: name, url: url)
    }
}

/// Lexical 편집기 상태(JSON)를 HTML로 바꾼다.
///
/// 글로벌미디어 API는 본문을 `{"editorState":{"root":...}}` 글자로 주고, 목록에서는 그 글자를
/// 한 번 더 JSON 글자로 감싸서 준다. 둘 다 받는다.
enum LexicalHTML {
    static func render(_ content: String) throws -> String {
        guard !content.isEmpty else { return "" }
        var value: Any = content
        // 글자 안에 JSON이 들어 있으면 풀어 낸다. 두 겹까지 본다.
        for _ in 0..<3 {
            guard let text = value as? String, let data = text.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { break }
            value = parsed
        }
        guard let object = value as? [String: Any] else {
            // JSON이 아니면 예전 글처럼 HTML이 그대로 온 것으로 본다.
            return value as? String ?? ""
        }
        let state = object["editorState"] as? [String: Any] ?? object
        guard let root = state["root"] as? [String: Any] else {
            throw NoticeError.decoding("Lexical 본문에 root 없음")
        }
        return children(of: root)
    }

    private static func children(of node: [String: Any]) -> String {
        (node["children"] as? [[String: Any]] ?? []).map(render(node:)).joined()
    }

    private static func render(node: [String: Any]) -> String {
        let type = node["type"] as? String ?? ""
        switch type {
        case "text", "hashtag", "tab", "code-highlight":
            return text(node)
        case "linebreak":
            return "<br>"
        case "paragraph":
            // 빈 문단은 편집기 화면처럼 빈 줄로 남긴다.
            let inner = children(of: node)
            return "<p\(blockStyle(node))>\(inner.isEmpty ? "<br>" : inner)</p>"
        case "heading":
            let tag = (node["tag"] as? String).flatMap { ["h1", "h2", "h3", "h4", "h5", "h6"].contains($0) ? $0 : nil } ?? "h3"
            return "<\(tag)\(blockStyle(node))>\(children(of: node))</\(tag)>"
        case "quote":
            return "<blockquote>\(children(of: node))</blockquote>"
        case "code":
            return "<pre><code>\(children(of: node))</code></pre>"
        case "list":
            let ordered = (node["tag"] as? String) == "ol" || (node["listType"] as? String) == "number"
            let start = (node["start"] as? Int).flatMap { ordered && $0 != 1 ? " start=\"\($0)\"" : nil } ?? ""
            return ordered ? "<ol\(start)>\(children(of: node))</ol>" : "<ul>\(children(of: node))</ul>"
        case "listitem":
            return "<li>\(children(of: node))</li>"
        case "link", "autolink":
            guard let href = safeURL(node["url"] as? String) else { return children(of: node) }
            return "<a href=\"\(JSONAPI.escapeHTML(href))\">\(children(of: node))</a>"
        case "image", "inline-image":
            guard let src = safeURL(node["src"] as? String) else { return "" }
            let alt = JSONAPI.escapeHTML(node["altText"] as? String ?? "")
            return "<img src=\"\(JSONAPI.escapeHTML(src))\" alt=\"\(alt)\">"
        case "horizontalrule":
            return "<hr>"
        case "table":
            return "<table>\(children(of: node))</table>"
        case "tablerow":
            return "<tr>\(children(of: node))</tr>"
        case "tablecell":
            let tag = (node["headerState"] as? Int ?? 0) > 0 ? "th" : "td"
            var attributes = ""
            if let span = node["colSpan"] as? Int, span > 1 { attributes += " colspan=\"\(span)\"" }
            if let span = node["rowSpan"] as? Int, span > 1 { attributes += " rowspan=\"\(span)\"" }
            return "<\(tag)\(attributes)>\(children(of: node))</\(tag)>"
        default:
            // 모르는 노드는 글자나 자식만 살린다.
            if node["text"] is String { return text(node) }
            return children(of: node)
        }
    }

    /// `format` 비트: 1 굵게, 2 기울임, 4 취소선, 8 밑줄, 16 코드, 32 아래첨자, 64 위첨자, 128 강조.
    private static func text(_ node: [String: Any]) -> String {
        var html = JSONAPI.escapeHTML(node["text"] as? String ?? "")
        let format = node["format"] as? Int ?? 0
        let tags: [(Int, String)] = [(16, "code"), (128, "mark"), (32, "sub"), (64, "sup"),
                                     (4, "s"), (8, "u"), (2, "em"), (1, "strong")]
        for (bit, tag) in tags where format & bit != 0 {
            html = "<\(tag)>\(html)</\(tag)>"
        }
        if let style = node["style"] as? String, !style.isEmpty {
            html = "<span style=\"\(JSONAPI.escapeHTML(style))\">\(html)</span>"
        }
        return html
    }

    private static func blockStyle(_ node: [String: Any]) -> String {
        var styles: [String] = []
        if let align = node["format"] as? String, ["center", "right", "justify"].contains(align) {
            styles.append("text-align: \(align)")
        }
        if let indent = node["indent"] as? Int, indent > 0 {
            styles.append("padding-left: \(indent * 2)em")
        }
        return styles.isEmpty ? "" : " style=\"\(styles.joined(separator: "; "))\""
    }

    /// `javascript:` 같은 주소는 버린다. 본문에 박힌 `data:image` 그림은 살린다.
    private static func safeURL(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let lower = raw.lowercased()
        if lower.hasPrefix("javascript:") || lower.hasPrefix("vbscript:") { return nil }
        if lower.hasPrefix("data:") && !lower.hasPrefix("data:image/") { return nil }
        return raw
    }
}
