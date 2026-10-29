//
//  NotissuApp.swift
//  Notissu
//
//  Copyright © 2026 Notissu. All rights reserved.
//

import SwiftUI
import SwiftData

@main
struct NotissuApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var app: AppModel
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: SavedNotice.self)
        } catch {
            fatalError("저장소를 열 수 없습니다: \(error)")
        }
        // 2.x 사용자가 첫 화면에서 게시판 고르기를 보지 않도록 화면을 그리기 전에 옮긴다.
        let model = AppModel()
        LegacyMigration.runIfNeeded(app: model, context: container.mainContext)
        _app = State(initialValue: model)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .task { await app.refreshCatalog() }
        }
        .modelContainer(container)
    }
}
