//
//  FeedModel.swift
//  Notissu
//
//  Copyright © 2026 Notissu. All rights reserved.
//

import Foundation
import Observation
import NoticeKit

/// 게시판 여러 곳의 글을 날짜순으로 합친 목록. 게시판 하나만 넘기면 그 게시판 목록이 된다.
@MainActor
@Observable
final class FeedModel {
    enum Phase: Equatable {
        case idle, loading, loaded, failed
    }

    let boards: [Board]
    let keyword: String?

    private(set) var items: [NoticeRef] = []
    private(set) var pinned: [NoticeRef] = []
    private(set) var phase: Phase = .idle
    private(set) var isLoadingMore = false
    /// 불러오지 못한 게시판 이름. 일부만 실패해도 나머지는 보여 준다.
    private(set) var failedBoards: [String] = []

    private var nextPage: [String: Int] = [:]
    private var exhausted: Set<String> = []

    init(boards: [Board], keyword: String? = nil) {
        self.boards = boards
        self.keyword = keyword?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    var canLoadMore: Bool {
        phase == .loaded && boards.contains { !exhausted.contains($0.id) }
    }

    func reload(using app: AppModel) async {
        phase = items.isEmpty ? .loading : phase
        nextPage = [:]
        exhausted = []
        let results = await fetch(boards: boards, pages: Dictionary(uniqueKeysWithValues: boards.map { ($0.id, 1) }), client: app.client)

        var fresh: [NoticeRef] = []
        var freshPinned: [NoticeRef] = []
        var failed: [String] = []
        for board in boards {
            guard let result = results[board.id] else { continue }
            switch result {
            case .success(let list):
                if keyword == nil {
                    app.prime(boardID: board.id, items: list)
                }
                freshPinned += list.filter(\.isPinned).map { NoticeRef(boardID: board.id, item: $0) }
                fresh += list.filter { !$0.isPinned }.map { NoticeRef(boardID: board.id, item: $0) }
                if list.isEmpty { exhausted.insert(board.id) } else { nextPage[board.id] = 2 }
            case .failure:
                failed.append(board.name)
                exhausted.insert(board.id)
            }
        }
        pinned = Self.unique(freshPinned)
        items = Self.sorted(Self.unique(fresh))
        failedBoards = failed
        phase = (items.isEmpty && pinned.isEmpty && failed.count == boards.count) ? .failed : .loaded
    }

    /// 아직 끝나지 않은 게시판마다 다음 페이지를 받아 합친다. 고정 공지는 매 페이지 되풀이되므로 버린다.
    func loadMore(using app: AppModel) async {
        guard canLoadMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let targets = boards.filter { !exhausted.contains($0.id) }
        let pages = Dictionary(uniqueKeysWithValues: targets.map { ($0.id, nextPage[$0.id] ?? 2) })
        let results = await fetch(boards: targets, pages: pages, client: app.client)

        let known = Set(items.map(\.id) + pinned.map(\.id))
        var fresh: [NoticeRef] = []
        for board in targets {
            guard case .success(let list)? = results[board.id] else {
                exhausted.insert(board.id)
                continue
            }
            let refs = list.filter { !$0.isPinned }.map { NoticeRef(boardID: board.id, item: $0) }.filter { !known.contains($0.id) }
            if refs.isEmpty {
                exhausted.insert(board.id)
            } else {
                fresh += refs
                nextPage[board.id] = (pages[board.id] ?? 2) + 1
            }
        }
        items = Self.sorted(Self.unique(items + fresh))
    }

    private func fetch(boards: [Board], pages: [String: Int], client: NoticeClient) async -> [String: Result<[NoticeItem], Error>] {
        let keyword = self.keyword
        // 작업 묶음에는 오류 값을 싣지 않는다. 출시 최적화 빌드에서 `Result<_, any Error>`를
        // 묶음 결과로 넘기면 작업이 끝나는 순간 앱이 죽었다(iOS 27, 2026-10-29).
        let lists = await withTaskGroup(of: (String, [NoticeItem]?).self) { group in
            for board in boards {
                let page = pages[board.id] ?? 1
                group.addTask {
                    (board.id, try? await client.list(board, page: page, keyword: keyword))
                }
            }
            var lists: [String: [NoticeItem]?] = [:]
            for await (id, list) in group {
                lists[id] = list
            }
            return lists
        }
        var results: [String: Result<[NoticeItem], Error>] = [:]
        for (id, list) in lists {
            results[id] = list.map { .success($0) } ?? .failure(FeedError.loadFailed)
        }
        return results
    }

    private static func unique(_ refs: [NoticeRef]) -> [NoticeRef] {
        var seen = Set<String>()
        return refs.filter { seen.insert($0.id).inserted }
    }

    /// 날짜 내림차순. 날짜가 없거나 같으면 원래 순서를 지킨다.
    private static func sorted(_ refs: [NoticeRef]) -> [NoticeRef] {
        refs.enumerated()
            .sorted { lhs, rhs in
                let l = lhs.element.item.date ?? "", r = rhs.element.item.date ?? ""
                return l != r ? l > r : lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}

enum FeedError: Error {
    case loadFailed
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
