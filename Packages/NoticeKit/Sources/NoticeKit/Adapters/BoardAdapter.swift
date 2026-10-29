import Foundation

struct AdapterContext: Sendable {
    let fetcher: HTTPFetcher
    let selectors: Board.Selectors
}

/// 엔진 하나가 목록과 상세를 읽는 방법.
protocol BoardAdapter: Sendable {
    func list(_ board: Board, page: Int, keyword: String?, context: AdapterContext) async throws -> [NoticeItem]
    func detail(_ board: Board, url: URL, context: AdapterContext) async throws -> NoticeDetail
}

extension Engine {
    var adapter: any BoardAdapter {
        switch self {
        case .html: HTMLAdapter()
        case .nextApiV1: NextApiV1Adapter()
        case .nextApiBoard: NextApiBoardAdapter()
        case .film: FilmAdapter()
        case .staticJSON: StaticJSONAdapter()
        case .pyxis: PyxisAdapter()
        }
    }
}

extension Board {
    var stringEncoding: String.Encoding {
        encoding.map(String.Encoding.init(charset:)) ?? .utf8
    }

    /// 검색어가 있으면 `search` 틀을, 없거나 비어 있으면 `list` 틀을 쓴다.
    func listURL(page: Int, keyword: String?) throws -> URL {
        let keyword = keyword?.trimmingCharacters(in: .whitespacesAndNewlines)
        let template = (keyword?.isEmpty == false ? search : nil) ?? list
        return try URLTemplate.url(template, page: page, pageSize: pageSize, keyword: keyword, encoding: stringEncoding)
    }

    func option(_ key: String) throws -> String {
        guard let value = options?[key] else {
            throw NoticeError.decoding("\(id): options.\(key) 없음")
        }
        return value
    }
}

struct UnsupportedAdapter: BoardAdapter {
    let engine: Engine

    func list(_ board: Board, page: Int, keyword: String?, context: AdapterContext) async throws -> [NoticeItem] {
        throw NoticeError.unsupported(engine.rawValue)
    }

    func detail(_ board: Board, url: URL, context: AdapterContext) async throws -> NoticeDetail {
        throw NoticeError.unsupported(engine.rawValue)
    }
}
