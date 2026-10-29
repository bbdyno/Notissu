//
//  NoticeRow.swift
//  Notissu
//
//  Copyright © 2026 Notissu. All rights reserved.
//

import SwiftUI
import NoticeKit

/// 목록 한 줄. 안 읽음 점, 게시판·날짜, 제목, 등록 부서·첨부·마감을 보여 준다.
struct NoticeRow: View {
    @Environment(AppModel.self) private var app

    let ref: NoticeRef
    /// 여러 게시판을 합친 목록이면 게시판 이름을, 한 게시판 목록이면 고정 표시를 맨 위에 둔다.
    let showsBoard: Bool

    var body: some View {
        let item = ref.item
        let isUnread = !app.isRead(ref)

        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(isUnread ? Theme.accent : .clear)
                .frame(width: 8, height: 8)
                .frame(width: 16)
                .padding(.top, 6)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(headline)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(item.isPinned && !showsBoard ? Theme.accentText : Theme.ink)
                    Spacer(minLength: 8)
                    Text(NoticeFormat.shortDate(item.date))
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                }
                Text(item.title)
                    .font(.system(size: 16, weight: isUnread ? .semibold : .regular))
                    .foregroundStyle(isUnread ? Theme.ink : Theme.readTitle)
                    .lineSpacing(2)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                meta
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(isUnread ? "안 읽음" : "")
    }

    private var headline: String {
        if showsBoard {
            return app.board(id: ref.boardID)?.name ?? ""
        }
        return ref.item.isPinned ? "고정" : (ref.item.author ?? "")
    }

    @ViewBuilder
    private var meta: some View {
        let item = ref.item
        let author = showsBoard ? item.author : nil
        let deadline = NoticeFormat.deadline(item)
        if author != nil || item.hasAttachment || deadline != nil {
            HStack(spacing: 8) {
                if let author {
                    Text(author)
                }
                if item.hasAttachment {
                    Label("첨부", systemImage: "paperclip")
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("첨부 있음")
                }
                if let deadline {
                    Text(deadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.accentText)
                }
            }
            .font(.footnote)
            .foregroundStyle(Theme.secondary)
        }
    }
}

/// 좁은 화면에서는 다음 화면으로 넘어가고, 넓은 화면에서는 본문 칸에 연다.
struct NoticeRowLink: View {
    @Environment(AppModel.self) private var app
    @Environment(Navigator.self) private var navigator
    @Environment(\.isSplitLayout) private var isSplit

    let ref: NoticeRef
    let showsBoard: Bool

    var body: some View {
        Button {
            app.markRead(ref)
            navigator.open(ref, isSplit: isSplit)
        } label: {
            NoticeRow(ref: ref, showsBoard: showsBoard)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 20))
        .listRowBackground(isSplit && navigator.selection?.id == ref.id ? Theme.accentBackground : Theme.background)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 24 }
        .listRowSeparatorTint(Theme.separator)
    }
}
