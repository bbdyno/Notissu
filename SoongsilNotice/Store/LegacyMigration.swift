//
//  LegacyMigration.swift
//  Notissu
//
//  Copyright © 2026 Notissu. All rights reserved.
//

import CoreData
import Foundation
import SwiftData
import NoticeKit

/// 2.x에서 쓰던 "내 학과"와 북마크를 3.0 구조로 한 번만 옮긴다.
@MainActor
enum LegacyMigration {
    private static let doneKey = "legacyMigrationDone"
    private static let appGroup = "group.com.elliott.Notissu"

    static func runIfNeeded(app: AppModel, context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        defer { defaults.set(true, forKey: doneKey) }

        migrateMyMajor(app: app, defaults: defaults)
        migrateFavorites(app: app, context: context)
    }

    /// 2.x는 `myDeptCode`에 학과 번호를 넣었다. 그 게시판과 학교 공지를 구독으로 옮긴다.
    private static func migrateMyMajor(app: AppModel, defaults: UserDefaults) {
        guard app.subscriptions.isEmpty, defaults.object(forKey: "myDeptCode") != nil else { return }
        let code = defaults.integer(forKey: "myDeptCode")
        var ids: [String] = []
        if let board = app.catalog.board(legacyCode: code) {
            ids.append(board.id)
        }
        if let school = app.catalog.board(legacyCode: 100), !ids.contains(school.id) {
            ids.append(school.id)
        }
        guard !ids.isEmpty else { return }
        app.subscriptions = ids
        app.isOnboarded = true
    }

    /// 2.x 북마크는 앱 그룹 폴더의 `Notissu.sqlite`(Core Data, 엔티티 `Favorite`)에 있다.
    private static func migrateFavorites(app: AppModel, context: ModelContext) {
        guard let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else { return }
        let storeURL = folder.appendingPathComponent("Notissu.sqlite")
        guard FileManager.default.fileExists(atPath: storeURL.path),
              let modelURL = Bundle.main.url(forResource: "FavoriteNotice", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            return
        }

        let container = NSPersistentContainer(name: "FavoriteNotice", managedObjectModel: model)
        // 읽기 전용으로 열면 SQLite 보조 파일(-wal, -shm)을 만들지 못해 실패하는 경우가 있어 보통으로 연다.
        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: storeURL)]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        guard loadError == nil else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "Favorite")
        guard let favorites = try? container.viewContext.fetch(request) else { return }

        for favorite in favorites {
            guard let url = favorite.value(forKey: "url") as? String, !url.isEmpty,
                  let title = favorite.value(forKey: "title") as? String else { continue }
            let code = (favorite.value(forKey: "deptCode") as? NSNumber)?.intValue ?? 0
            let board = app.catalog.board(legacyCode: code)
            let date = NoticeDate.normalize(favorite.value(forKey: "date") as? String)
            context.insert(SavedNotice(url: url, title: title, boardID: board?.id ?? "",
                                       boardName: board?.name ?? "", date: date))
        }
        try? context.save()
    }
}
