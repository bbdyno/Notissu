import Foundation

/// 중앙도서관 Pyxis (`{api}/<홈페이지>/bulletin-boards/<게시판>/bulletins?offset=&max=`).
///
/// 목록에는 본문이 없어서 상세는 `options.detail` 틀(`{api}/1/bulletins/1/{id}`)로 다시 부른다.
/// 첨부의 `originalImageUrl`은 `/attachments/...`처럼 `{api}` 아래 경로로 온다.
///
/// 고정 공지는 목록에 표시가 없고, 화면이 `onlyNoticableBulletin=true`로 따로 불러 위에 얹는다.
/// `options.pinned` 틀이 있으면 검색이 아닌 1페이지에만 같은 방식으로 얹는다. 이때 `list`에
/// `onlyNoticableBulletin=false`를 넣어 고정 공지가 일반 목록에 한 번 더 나오지 않게 한다.
///
/// 날짜는 `options.date`가 `lastUpdated`면 수정 시각을, 아니면 작성 시각(`dateCreated`)을 쓴다.
/// 중앙도서관 목록 화면은 수정 시각을 보여 준다.
///
/// 설정: `list`/`search`는 `{api}`와 `{offset}`을 쓰고(`pageSize`가 `max`와 같아야 함),
/// `options.api`(`https://<host>/pyxis-api`), `options.view`(상세 화면 틀), `options.detail`(상세 API 틀).
struct PyxisAdapter: BoardAdapter {
    func list(_ board: Board, page: Int, keyword: String?, context: AdapterContext) async throws -> [NoticeItem] {
        let url = try board.apiListURL(page: page, keyword: keyword)
        let response = try await context.fetcher.decode(PyxisParser.ListResponse.self, from: url)
        let items = try PyxisParser.list(response, board: board)
        guard page <= 1, Board.trimmedKeyword(keyword) == nil, let template = board.options?["pinned"] else {
            return items
        }
        let pinnedResponse = try await context.fetcher.decode(PyxisParser.ListResponse.self, from: try board.apiURL(template))
        return PyxisParser.merge(pinned: try PyxisParser.list(pinnedResponse, board: board, pinned: true), items: items)
    }

    func detail(_ board: Board, url: URL, context: AdapterContext) async throws -> NoticeDetail {
        let id = try board.itemID(from: url)
        let apiURL = try board.apiURL(board.option("detail"), values: ["id": id])
        let response = try await context.fetcher.decode(PyxisParser.DetailResponse.self, from: apiURL)
        return try PyxisParser.detail(response, url: url, board: board)
    }
}

enum PyxisParser {
    struct ListResponse: Decodable {
        struct Page: Decodable {
            let list: [Post]?
        }
        let success: Bool?
        let code: String?
        let data: Page?
    }

    struct DetailResponse: Decodable {
        let success: Bool?
        let code: String?
        let data: Post?
    }

    struct Post: Decodable {
        struct Attachment: Decodable {
            let logicalName: String?
            let originalImageUrl: String?
        }
        let id: String
        let title: String
        let content: String?
        let writer: String?
        let isPrivate: Bool?
        let dateCreated: String?
        let lastUpdated: String?
        let attachmentCnt: Int?
        let attachments: [Attachment]?
    }

    static func list(_ response: ListResponse, board: Board, pinned: Bool = false) throws -> [NoticeItem] {
        // 글이 없으면 `success.noRecord`와 함께 `list`가 빠져서 온다.
        if response.code == "success.noRecord" { return [] }
        guard let posts = response.data?.list else {
            throw NoticeError.decoding("\(board.id): 목록 응답에 data.list 없음 (\(response.code ?? "-"))")
        }
        return try posts.filter { $0.isPrivate != true }.map { post in
            NoticeItem(title: HTMLBoardParser.clean(post.title),
                       url: try board.viewURL(id: post.id),
                       date: date(post, board: board),
                       isPinned: pinned,
                       hasAttachment: (post.attachmentCnt ?? post.attachments?.count ?? 0) > 0,
                       author: post.writer)
        }
    }

    static func detail(_ response: DetailResponse, url: URL, board: Board) throws -> NoticeDetail {
        guard let post = response.data else {
            throw NoticeError.noContent("상세 응답에 data 없음 (\(response.code ?? "-")): \(url.absoluteString)")
        }
        let api = try board.option("api")
        let attachments: [NoticeAttachment] = (post.attachments ?? []).compactMap { attachment in
            guard let path = attachment.originalImageUrl, !path.isEmpty,
                  let fileURL = URL(string: path.hasPrefix("http") ? path : api + path, encodingInvalidCharacters: true) else {
                return nil
            }
            let name = HTMLBoardParser.clean(attachment.logicalName)
            return NoticeAttachment(name: name.isEmpty ? fileURL.lastPathComponent : name, url: fileURL)
        }
        return NoticeDetail(url: url, title: HTMLBoardParser.clean(post.title),
                            date: date(post, board: board),
                            bodyHTML: post.content ?? "", attachments: attachments)
    }

    /// 고정 공지를 위에 두고, 일반 목록에 같은 글이 있으면 뺀다.
    static func merge(pinned: [NoticeItem], items: [NoticeItem]) -> [NoticeItem] {
        let pinnedURLs = Set(pinned.map(\.url))
        return pinned + items.filter { !pinnedURLs.contains($0.url) }
    }

    static func date(_ post: Post, board: Board) -> String? {
        let preferred = board.options?["date"] == "lastUpdated" ? post.lastUpdated : post.dateCreated
        return NoticeDate.normalize(preferred ?? post.dateCreated)
    }
}
