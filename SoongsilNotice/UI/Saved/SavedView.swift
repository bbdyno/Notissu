//
//  SavedView.swift
//  Notissu
//
//  Copyright © 2026 Notissu. All rights reserved.
//

import SwiftUI
import SwiftData

/// 저장한 공지. 저장한 순서대로, 밀어서 지운다.
struct SavedView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedNotice.savedAt, order: .reverse) private var saved: [SavedNotice]

    var body: some View {
        List {
            if saved.isEmpty {
                StatusMessage(symbol: "bookmark", text: "저장한 공지가 없습니다.\n공지를 열고 저장 단추를 누르면 여기에 모입니다.")
            }
            ForEach(saved) { notice in
                if let ref = notice.ref {
                    NoticeRowLink(ref: ref, showsBoard: true)
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    context.delete(saved[index])
                }
                try? context.save()
            }
        }
        .listStyle(.plain)
        .navigationTitle("저장")
    }
}
