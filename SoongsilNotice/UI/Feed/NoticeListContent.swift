//
//  NoticeListContent.swift
//  Notissu
//
//  Copyright © 2026 Notissu. All rights reserved.
//

import SwiftUI
import NoticeKit

/// 목록 모델 하나를 행으로 그린다. 불러오는 중·실패·빈 목록과 끝에서 더 불러오기를 맡는다.
struct NoticeListContent: View {
    @Environment(AppModel.self) private var app

    let model: FeedModel
    let showsBoard: Bool
    /// 한 게시판 목록이면 고정 공지를 맨 위에 그대로 둔다.
    let showsPinnedInline: Bool
    var emptyMessage = "올라온 글이 없습니다."

    var body: some View {
        switch model.phase {
        case .idle, .loading:
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 40)
            .listRowSeparator(.hidden)
        case .failed:
            StatusMessage(symbol: "wifi.exclamationmark", text: "게시판을 불러오지 못했습니다.\n당겨서 다시 시도해 주세요.")
        case .loaded:
            if showsPinnedInline {
                ForEach(model.pinned) { ref in
                    NoticeRowLink(ref: ref, showsBoard: showsBoard)
                }
            }
            if model.items.isEmpty && (!showsPinnedInline || model.pinned.isEmpty) {
                StatusMessage(symbol: "tray", text: emptyMessage)
            }
            ForEach(model.items) { ref in
                NoticeRowLink(ref: ref, showsBoard: showsBoard)
                    .onAppear {
                        if ref.id == model.items.last?.id {
                            Task { await model.loadMore(using: app) }
                        }
                    }
            }
            if model.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
            if !model.failedBoards.isEmpty {
                Text("불러오지 못한 게시판: \(model.failedBoards.joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
                    .listRowSeparator(.hidden)
            }
        }
    }
}

struct StatusMessage: View {
    let symbol: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Theme.secondary)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .listRowSeparator(.hidden)
    }
}
