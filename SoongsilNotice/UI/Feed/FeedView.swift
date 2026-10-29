//
//  FeedView.swift
//  Notissu
//
//  Copyright © 2026 Notissu. All rights reserved.
//

import SwiftUI
import NoticeKit

/// 소식. 구독한 게시판의 글을 날짜순으로 모아 보여 준다.
struct FeedView: View {
    @Environment(AppModel.self) private var app
    @Environment(Navigator.self) private var navigator

    /// 고른 게시판. `nil`이면 전체.
    @State private var filter: String?
    @State private var models: [String: FeedModel] = [:]
    @State private var model: FeedModel?
    @State private var query = ""
    @State private var submittedQuery = ""

    private var boards: [Board] {
        if let filter, let board = app.board(id: filter) {
            return [board]
        }
        return app.subscribedBoards
    }

    private var modelKey: String {
        [filter ?? "*", submittedQuery, app.subscriptions.joined(separator: ",")].joined(separator: "|")
    }

    var body: some View {
        List {
            if !app.subscriptions.isEmpty {
                filterBar
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                if filter == nil, submittedQuery.isEmpty, let model, !model.pinned.isEmpty {
                    pinnedShortcut(count: model.pinned.count)
                }
            }
            if app.subscriptions.isEmpty {
                noSubscriptions
            } else if let model {
                NoticeListContent(model: model, showsBoard: filter == nil, showsPinnedInline: filter != nil,
                                  emptyMessage: submittedQuery.isEmpty ? "올라온 글이 없습니다." : "찾는 글이 없습니다.")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("소식")
        .searchable(text: $query, prompt: "구독한 게시판에서 찾기")
        .onSubmit(of: .search) { submittedQuery = query }
        .onChange(of: query) { _, newValue in
            if newValue.isEmpty { submittedQuery = "" }
        }
        .refreshable { await model?.reload(using: app) }
        .task(id: modelKey) { await prepareModel() }
    }

    private func prepareModel() async {
        guard !boards.isEmpty else {
            model = nil
            return
        }
        if filter != nil, !app.subscriptions.contains(filter ?? "") {
            filter = nil
            return
        }
        let current = models[modelKey] ?? FeedModel(boards: boards, keyword: submittedQuery.nilIfEmpty)
        models[modelKey] = current
        model = current
        if current.phase == .idle {
            await current.reload(using: app)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                filterTab(title: "전체", id: nil)
                ForEach(app.subscribedBoards) { board in
                    filterTab(title: board.name, id: board.id)
                }
            }
            .padding(.horizontal, 20)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.separator).frame(height: 1)
        }
    }

    private func filterTab(title: String, id: String?) -> some View {
        let isSelected = filter == id
        return Button {
            filter = id
        } label: {
            Text(title)
                .font(.subheadline.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? Theme.ink : Theme.secondary)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(isSelected ? Theme.ink : .clear).frame(height: 2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func pinnedShortcut(count: Int) -> some View {
        Button {
            navigator.paths[navigator.selectedTab, default: []].append(.pinned)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "pin")
                    .accessibilityHidden(true)
                Text("고정 공지 모아 보기")
                    .fontWeight(.semibold)
                Text("\(count)")
                    .foregroundStyle(Theme.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.secondary)
                    .accessibilityHidden(true)
            }
            .font(.subheadline)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Theme.groupedBackground, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
        .listRowSeparator(.hidden)
    }

    private var noSubscriptions: some View {
        VStack(spacing: 14) {
            StatusMessage(symbol: "square.grid.2x2", text: "구독한 게시판이 없습니다.\n학과나 학교 게시판을 골라 주세요.")
            Button("게시판 고르기") {
                navigator.selectedTab = .boards
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accentText)
        }
        .listRowSeparator(.hidden)
    }
}

/// 구독한 게시판의 고정 공지만 게시판별로 모아 본다.
struct PinnedView: View {
    @Environment(AppModel.self) private var app
    @State private var model: FeedModel?

    var body: some View {
        List {
            if let model {
                switch model.phase {
                case .idle, .loading:
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .padding(.vertical, 40)
                        .listRowSeparator(.hidden)
                default:
                    ForEach(app.subscribedBoards) { board in
                        let refs = model.pinned.filter { $0.boardID == board.id }
                        if !refs.isEmpty {
                            Section(board.name) {
                                ForEach(refs) { ref in
                                    NoticeRowLink(ref: ref, showsBoard: false)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("고정 공지")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model?.reload(using: app) }
        .task {
            if model == nil {
                let fresh = FeedModel(boards: app.subscribedBoards)
                model = fresh
                await fresh.reload(using: app)
            }
        }
    }
}
