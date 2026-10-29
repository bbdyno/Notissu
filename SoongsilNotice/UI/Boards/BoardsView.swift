//
//  BoardsView.swift
//  Notissu
//
//  Copyright © 2026 Notissu. All rights reserved.
//

import SwiftUI
import NoticeKit

/// 게시판 찾기. 학부·대학원·학교로 나누고 소속별로 묶는다.
struct BoardsView: View {
    @Environment(AppModel.self) private var app
    @State private var program: Board.Program = .undergraduate
    @State private var query = ""

    var body: some View {
        List {
            if query.isEmpty {
                Picker("구분", selection: $program) {
                    Text("학부").tag(Board.Program.undergraduate)
                    Text("대학원").tag(Board.Program.graduate)
                    Text("학교").tag(Board.Program.campus)
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
            }
            BoardSections(boards: visibleBoards) { board in
                NavigationLink(value: Route.board(board)) {
                    BoardRow(board: board, showsCollege: !query.isEmpty)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("게시판")
        .searchable(text: $query, prompt: "학과나 게시판 이름")
    }

    private var visibleBoards: [Board] {
        let keyword = query.trimmingCharacters(in: .whitespaces)
        if keyword.isEmpty {
            return app.catalog.boards.filter { $0.program == program }
        }
        return app.catalog.boards.filter { $0.name.localizedCaseInsensitiveContains(keyword) || $0.college.localizedCaseInsensitiveContains(keyword) }
    }
}

/// 게시판을 소속(단과대학 등)별 섹션으로 나눈다. 설정 파일의 순서를 따른다.
struct BoardSections<Row: View>: View {
    let boards: [Board]
    @ViewBuilder let row: (Board) -> Row

    var body: some View {
        ForEach(groups, id: \.title) { group in
            Section {
                ForEach(group.boards) { board in
                    row(board)
                }
            } header: {
                Text(group.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.secondary)
            }
        }
    }

    private var groups: [(title: String, boards: [Board])] {
        var order: [String] = []
        var grouped: [String: [Board]] = [:]
        for board in boards {
            let title = Self.sectionTitle(board)
            if grouped[title] == nil { order.append(title) }
            grouped[title, default: []].append(board)
        }
        return order.map { ($0, grouped[$0] ?? []) }
    }

    private static func sectionTitle(_ board: Board) -> String {
        switch board.college {
        case "(독립)": return "독립 학과·학부"
        case "대학원": return "대학원"
        case "일반대학원": return "일반대학원 학과"
        case "본부": return "학교"
        default: return board.college
        }
    }
}

struct BoardRow: View {
    @Environment(AppModel.self) private var app
    let board: Board
    var showsCollege = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(board.name)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                if showsCollege {
                    Text(board.college)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                }
            }
            Spacer()
            if app.isSubscribed(board) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
                    .accessibilityLabel("구독 중")
            }
        }
        .frame(minHeight: 36)
    }
}

/// 게시판 하나의 글 목록. 고정 공지를 위에 두고 검색할 수 있다.
struct BoardNoticesView: View {
    @Environment(AppModel.self) private var app
    let board: Board

    @State private var models: [String: FeedModel] = [:]
    @State private var model: FeedModel?
    @State private var query = ""
    @State private var submittedQuery = ""

    var body: some View {
        list
            .navigationTitle(board.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if let web = board.web.flatMap({ URL(string: $0, encodingInvalidCharacters: true) }) {
                        Link(destination: web) {
                            Image(systemName: "safari")
                        }
                        .accessibilityLabel("게시판 원문 열기")
                    }
                    Button {
                        app.toggleSubscription(board)
                    } label: {
                        Image(systemName: app.isSubscribed(board) ? "checkmark.circle.fill" : "plus.circle")
                    }
                    .accessibilityLabel(app.isSubscribed(board) ? "구독 그만하기" : "구독하기")
                }
            }
            .refreshable { await model?.reload(using: app) }
            .task(id: submittedQuery) {
                let current = models[submittedQuery] ?? FeedModel(boards: [board], keyword: submittedQuery.nilIfEmpty)
                models[submittedQuery] = current
                model = current
                if current.phase == .idle {
                    await current.reload(using: app)
                }
            }
    }

    @ViewBuilder
    private var list: some View {
        let content = List {
            if let model {
                NoticeListContent(model: model, showsBoard: false, showsPinnedInline: submittedQuery.isEmpty,
                                  emptyMessage: submittedQuery.isEmpty ? "올라온 글이 없습니다." : "찾는 글이 없습니다.")
            }
        }
        .listStyle(.plain)

        if board.supportsSearch {
            content
                .searchable(text: $query, prompt: "\(board.name)에서 찾기")
                .onSubmit(of: .search) { submittedQuery = query }
                .onChange(of: query) { _, newValue in
                    if newValue.isEmpty { submittedQuery = "" }
                }
        } else {
            content
        }
    }
}
