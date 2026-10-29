import Foundation

/// 가상융합대학원 (`/data/content.json`).
///
/// 사이트가 정적 JSON 하나에 모든 글을 담아 두고 화면에서 그린다. 전체를 받아 `pageSize`씩 잘라 주고,
/// 상세도 같은 파일을 다시 받아 글 번호로 찾는다. 검색은 화면 안에서만 하므로 지원하지 않는다.
///
/// 설정: `list`는 JSON 주소, `pageSize`(기본 15), `options.view`(상세 화면 틀, 예: `…/notice.html?id={id}`),
/// `options.key`(글 배열 이름, 기본 `notice`). 본문 속 상대 주소는 상세 화면 주소를 기준으로 푼다.
struct StaticJSONAdapter: BoardAdapter {
    func list(_ board: Board, page: Int, keyword: String?, context: AdapterContext) async throws -> [NoticeItem] {
        let posts = try await fetchPosts(board, context: context)
        return try StaticJSONParser.list(posts, page: page, board: board)
    }

    func detail(_ board: Board, url: URL, context: AdapterContext) async throws -> NoticeDetail {
        let id = try board.itemID(from: url)
        let posts = try await fetchPosts(board, context: context)
        guard let post = posts.first(where: { $0.id == id }) else {
            throw NoticeError.noContent("글이 없음: \(url.absoluteString)")
        }
        return StaticJSONParser.detail(post, url: url)
    }

    private func fetchPosts(_ board: Board, context: AdapterContext) async throws -> [StaticJSONParser.Post] {
        let url = try board.apiURL(board.list)
        let (data, _) = try await context.fetcher.data(from: url, accept: "application/json")
        return try StaticJSONParser.posts(data, board: board, url: url)
    }
}

enum StaticJSONParser {
    struct Post: Decodable {
        struct Block: Decodable {
            let type: String?
            let html: String?
            let src: String?
        }
        let id: String
        let title: String
        let date: String?
        let pinned: Bool?
        let link: String?
        let image: String?
        let body: [Block]?
    }

    static let defaultPageSize = 15

    static func posts(_ data: Data, board: Board, url: URL? = nil) throws -> [Post] {
        let key = board.options?["key"] ?? "notice"
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let array = object[key] else {
            throw NoticeError.decoding("\(board.id): JSON에 \(key) 배열이 없음 \(url?.absoluteString ?? "")")
        }
        let arrayData = try JSONSerialization.data(withJSONObject: array)
        return try JSONAPI.decode([Post].self, from: arrayData, url: url)
    }

    /// 사이트 화면과 같이 파일에 적힌 순서대로 보여 준다.
    static func list(_ posts: [Post], page: Int, board: Board) throws -> [NoticeItem] {
        let size = max(board.pageSize ?? defaultPageSize, 1)
        let start = (max(page, 1) - 1) * size
        guard start < posts.count else { return [] }
        return try posts[start..<min(start + size, posts.count)].map { post in
            let url = try board.viewURL(id: post.id)
            return NoticeItem(title: HTMLBoardParser.clean(post.title),
                              url: url,
                              date: NoticeDate.normalize(post.date),
                              isPinned: post.pinned ?? false,
                              hasAttachment: fileLink(post, base: url) != nil)
        }
    }

    static func detail(_ post: Post, url: URL) -> NoticeDetail {
        var body = (post.body ?? []).map { block -> String in
            if block.type == "img" {
                guard let src = block.src.flatMap({ resolve($0, base: url) }) else { return "" }
                return "<img src=\"\(JSONAPI.escapeHTML(src.absoluteString))\" alt=\"\">"
            }
            return "<p>\(block.html ?? "")</p>"
        }.joined()
        if body.isEmpty, let image = post.image.flatMap({ resolve($0, base: url) }) {
            body = "<img src=\"\(JSONAPI.escapeHTML(image.absoluteString))\" alt=\"\">"
        }

        // 화면은 `link`를 "관련 링크 열기" 단추로 보여 준다. 파일이면 첨부로도 넣는다.
        var attachments: [NoticeAttachment] = []
        if let file = fileLink(post, base: url) {
            attachments.append(NoticeAttachment(name: file.lastPathComponent, url: file))
        }
        if let link = post.link.flatMap({ resolve($0, base: url) }) {
            body += "<p><a href=\"\(JSONAPI.escapeHTML(link.absoluteString))\">관련 링크 열기</a></p>"
        }
        return NoticeDetail(url: url, title: HTMLBoardParser.clean(post.title), date: NoticeDate.normalize(post.date),
                            bodyHTML: body, attachments: attachments)
    }

    static let fileExtensions: Set<String> = ["pdf", "hwp", "hwpx", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "zip", "txt"]

    /// `link`가 문서 파일을 가리키면 그 주소.
    static func fileLink(_ post: Post, base: URL) -> URL? {
        guard let link = post.link.flatMap({ resolve($0, base: base) }),
              fileExtensions.contains(link.pathExtension.lowercased()) else { return nil }
        return link
    }

    static func resolve(_ raw: String, base: URL) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.lowercased().hasPrefix("javascript:") else { return nil }
        return URL(string: trimmed, relativeTo: base)?.absoluteURL
    }
}
