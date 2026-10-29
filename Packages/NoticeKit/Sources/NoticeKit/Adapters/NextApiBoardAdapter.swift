import Foundation

/// AI전문대학원·중소기업대학원 (`{api}/board/content/list?pageNum=&boardEnName=`).
///
/// 목록 응답에 본문과 첨부가 같이 오지만, 상세는 글 번호만으로 열 수 있어야 해서
/// `{api}/board/content/{id}`를 부른다. 제목과 본문은 HTML 엔티티로 한 번 감싸서 오므로 푼다.
/// 고정 공지(`noticeYn` = `Y`)는 모든 페이지와 검색 결과에 다시 딸려 온다.
///
/// 설정: `list`/`search`는 `{api}`와 `{page}`를 쓰고, `options.api`(`https://<host>/api`), `options.view`(상세 화면 틀).
/// 상세·첨부 틀은 `options.detail`, `options.file`로 덮어쓸 수 있다.
struct NextApiBoardAdapter: BoardAdapter {
    func list(_ board: Board, page: Int, keyword: String?, context: AdapterContext) async throws -> [NoticeItem] {
        let url = try board.apiListURL(page: page, keyword: keyword)
        let response = try await context.fetcher.decode(NextApiBoardParser.ListResponse.self, from: url)
        return JSONAPI.dropUnrelatedPinned(try NextApiBoardParser.list(response, board: board), keyword: keyword)
    }

    func detail(_ board: Board, url: URL, context: AdapterContext) async throws -> NoticeDetail {
        let id = try board.itemID(from: url)
        let apiURL = try board.apiURL(option: "detail", default: "{api}/board/content/{id}", values: ["id": id])
        let response = try await context.fetcher.decode(NextApiBoardParser.DetailResponse.self, from: apiURL)
        return try NextApiBoardParser.detail(response, url: url, board: board)
    }
}

enum NextApiBoardParser {
    struct ListResponse: Decodable {
        struct Payload: Decodable {
            let content: Page?
        }
        struct Page: Decodable {
            let list: [Post]
        }
        let message: String?
        let data: Payload?
    }

    struct DetailResponse: Decodable {
        let message: String?
        let data: Post?
    }

    struct Post: Decodable {
        struct File: Decodable {
            let fileId: Int
            let fileOriginName: String?
        }
        let boardContentId: Int
        let boardTitle: String
        let boardContent: String?
        let noticeYn: String?
        let regDate: String?
        let fileList: [File]?
    }

    static func list(_ response: ListResponse, board: Board) throws -> [NoticeItem] {
        guard let posts = response.data?.content?.list else {
            throw NoticeError.decoding("\(board.id): 목록 응답에 data.content.list 없음 (\(response.message ?? "-"))")
        }
        return try posts.map { post in
            NoticeItem(title: title(post),
                       url: try board.viewURL(id: String(post.boardContentId)),
                       // 사이트는 `regDate`를 시간대 변환 없이 `YYYY.MM.DD`로 보여 준다.
                       date: NoticeDate.normalize(post.regDate),
                       isPinned: post.noticeYn == "Y",
                       hasAttachment: !(post.fileList ?? []).isEmpty)
        }
    }

    static func detail(_ response: DetailResponse, url: URL, board: Board) throws -> NoticeDetail {
        guard let post = response.data else {
            throw NoticeError.noContent("상세 응답에 data 없음 (\(response.message ?? "-")): \(url.absoluteString)")
        }
        let attachments = try (post.fileList ?? []).map { file in
            let fileURL = try board.apiURL(option: "file", default: "{api}/resource/download/{id}", values: ["id": String(file.fileId)])
            let name = HTMLBoardParser.clean(file.fileOriginName)
            return NoticeAttachment(name: name.isEmpty ? "첨부파일 \(file.fileId)" : name, url: fileURL)
        }
        return NoticeDetail(url: url,
                            title: title(post),
                            date: NoticeDate.normalize(post.regDate),
                            bodyHTML: JSONAPI.unescapeHTMLSource(post.boardContent ?? ""),
                            attachments: attachments)
    }

    static func title(_ post: Post) -> String {
        HTMLBoardParser.clean(JSONAPI.decodeEntities(post.boardTitle))
    }
}
