//
//  SavedNotice.swift
//  Notissu
//
//  Copyright © 2026 Notissu. All rights reserved.
//

import Foundation
import SwiftData
import NoticeKit

/// 저장한 공지. 게시판이 글을 지워도 제목과 주소는 남는다.
@Model
final class SavedNotice {
    @Attribute(.unique) var url: String
    var title: String
    var boardID: String
    var boardName: String
    var date: String?
    var savedAt: Date

    init(url: String, title: String, boardID: String, boardName: String, date: String?, savedAt: Date = Date()) {
        self.url = url
        self.title = title
        self.boardID = boardID
        self.boardName = boardName
        self.date = date
        self.savedAt = savedAt
    }

    convenience init(ref: NoticeRef, boardName: String) {
        self.init(url: ref.item.url.absoluteString, title: ref.item.title, boardID: ref.boardID,
                  boardName: boardName, date: ref.item.date)
    }

    var ref: NoticeRef? {
        guard let url = URL(string: url) else { return nil }
        return NoticeRef(boardID: boardID, item: NoticeItem(title: title, url: url, date: date))
    }
}
