import Foundation

/// 영화예술전공 (`{api}/notice/notice_list?LastNoticeIndex=`).
///
/// 페이지 번호가 없고, 앞 목록의 마지막 `NoticeIndex`를 커서로 넘겨 다음 10개를 받는다.
/// 그래서 `page`번째 목록은 앞 페이지를 차례로 불러 커서를 얻은 뒤 받는다. 검색과 고정 공지는 없다.
/// 상세는 화면이 모달로 여는 `{api}/notice/notice_view?NoticeIndex=`를 부른다.
///
/// 설정: `list`는 `{api}`와 `{cursor}`를 쓰고, `options.api`(사이트 주소), `options.view`(상세 화면 틀).
/// 상세 틀은 `options.detail`로 덮어쓸 수 있다.
struct FilmAdapter: BoardAdapter {
    func list(_ board: Board, page: Int, keyword: String?, context: AdapterContext) async throws -> [NoticeItem] {
        var cursor = "0"
        for _ in 1..<max(page, 1) {
            let response = try await fetchList(board, cursor: cursor, context: context)
            guard let last = response.posts.last?.NoticeIndex, response.restCount ?? 1 > 0 else { return [] }
            cursor = last
        }
        return try FilmParser.list(try await fetchList(board, cursor: cursor, context: context), board: board)
    }

    func detail(_ board: Board, url: URL, context: AdapterContext) async throws -> NoticeDetail {
        let id = try board.itemID(from: url)
        let apiURL = try board.apiURL(option: "detail", default: "{api}/notice/notice_view?NoticeIndex={id}", values: ["id": id])
        let response = try await context.fetcher.decode(FilmParser.DetailResponse.self, from: apiURL)
        return try FilmParser.detail(response, url: url, board: board)
    }

    private func fetchList(_ board: Board, cursor: String, context: AdapterContext) async throws -> FilmParser.ListResponse {
        let url = try board.apiURL(board.list, values: ["cursor": cursor])
        return try await context.fetcher.decode(FilmParser.ListResponse.self, from: url)
    }
}

enum FilmParser {
    struct ListResponse: Decodable {
        /// 글이 없으면 배열 대신 `false`가 온다.
        let data_list: FalseOr<[Post]>?
        let restCount: Int?

        var posts: [Post] { data_list?.value ?? [] }
    }

    struct DetailResponse: Decodable {
        let data_modify: FalseOr<Post>?
    }

    struct Post: Decodable {
        let NoticeIndex: String
        let Title: String
        let Content: String?
        let RegDate: String?
        let FileData: String?
        let OrgFile: String?
        let Image: String?

        var hasFile: Bool { !(FileData ?? "").isEmpty }
    }

    /// PHP가 빈 결과를 `false`로 주는 자리.
    struct FalseOr<T: Decodable>: Decodable {
        let value: T?

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if (try? container.decode(Bool.self)) != nil {
                value = nil
            } else {
                value = try container.decode(T.self)
            }
        }
    }

    static func list(_ response: ListResponse, board: Board) throws -> [NoticeItem] {
        try response.posts.map { post in
            NoticeItem(title: title(post),
                       url: try board.viewURL(id: post.NoticeIndex),
                       date: NoticeDate.normalize(post.RegDate),
                       hasAttachment: post.hasFile)
        }
    }

    static func detail(_ response: DetailResponse, url: URL, board: Board) throws -> NoticeDetail {
        guard let post = response.data_modify?.value else {
            throw NoticeError.noContent("글이 없음: \(url.absoluteString)")
        }
        // 화면 모달과 같이 대표 그림을 본문 위에 둔다.
        var body = post.Content ?? ""
        if let image = post.Image, !image.isEmpty {
            let src = try board.apiURL("{api}/resource/upload/notice/{id}", values: ["id": image])
            body = "<p><img src=\"\(JSONAPI.escapeHTML(src.absoluteString))\" alt=\"\"></p>" + body
        }

        var attachments: [NoticeAttachment] = []
        if let file = post.FileData, !file.isEmpty {
            let name = post.OrgFile.flatMap { $0.isEmpty ? nil : $0 } ?? file
            var components = URLComponents(url: try board.apiURL("{api}/download_file"), resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "filename", value: name),
                                      URLQueryItem(name: "filepath", value: "/resource/upload/notice/\(file)")]
            if let fileURL = components?.url {
                attachments.append(NoticeAttachment(name: name, url: fileURL))
            }
        }
        return NoticeDetail(url: url, title: title(post), date: NoticeDate.normalize(post.RegDate),
                            bodyHTML: body, attachments: attachments)
    }

    static func title(_ post: Post) -> String {
        HTMLBoardParser.clean(JSONAPI.decodeEntities(post.Title))
    }
}
