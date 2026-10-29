import Foundation

/// 앱과 점검 도구가 공지를 읽을 때 쓰는 진입점.
public struct NoticeClient: Sendable {
    public let catalog: BoardCatalog
    public let fetcher: HTTPFetcher

    public init(catalog: BoardCatalog, fetcher: HTTPFetcher = HTTPFetcher()) {
        self.catalog = catalog
        self.fetcher = fetcher
    }

    /// 목록 한 페이지. `page`는 1부터 센다.
    public func list(_ board: Board, page: Int = 1, keyword: String? = nil) async throws -> [NoticeItem] {
        try await board.engine.adapter.list(board, page: page, keyword: keyword, context: context(for: board))
    }

    public func detail(_ board: Board, url: URL) async throws -> NoticeDetail {
        try await board.engine.adapter.detail(board, url: url, context: context(for: board))
    }

    private func context(for board: Board) -> AdapterContext {
        AdapterContext(fetcher: fetcher, selectors: catalog.selectors(for: board))
    }
}
