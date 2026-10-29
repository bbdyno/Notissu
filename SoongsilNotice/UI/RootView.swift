//
//  RootView.swift
//  Notissu
//
//  Copyright © 2026 Notissu. All rights reserved.
//

import SwiftUI
import NoticeKit

/// 좁은 화면(아이폰, 접은 듀오)은 아래 탭, 넓은 화면(펼친 듀오, 아이패드)은 메뉴 줄 + 목록 칸 + 본문 칸.
struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var navigator = Navigator()

    private var isSplit: Bool { horizontalSizeClass == .regular }

    var body: some View {
        Group {
            if isSplit {
                SplitRootView()
            } else {
                TabRootView()
            }
        }
        .environment(navigator)
        .environment(\.isSplitLayout, isSplit)
        .tint(Theme.accentText)
        .onChange(of: isSplit) { _, newValue in
            navigator.adapt(toSplit: newValue)
        }
        .fullScreenCover(isPresented: Binding(get: { !app.isOnboarded }, set: { _ in })) {
            OnboardingView()
                .environment(app)
        }
        .onOpenURL { url in
            // 2.x 위젯이 쓰던 notissu://?index=N 은 탭 번호다.
            let index = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "index" }?.value.flatMap(Int.init)
            if let index, AppTab.allCases.indices.contains(index) {
                navigator.selectedTab = AppTab.allCases[index]
            }
        }
    }
}

/// 탭마다 쌓이는 화면.
struct TabStack: View {
    @Environment(Navigator.self) private var navigator
    let tab: AppTab

    var body: some View {
        NavigationStack(path: Binding(
            get: { navigator.path(for: tab) },
            set: { navigator.setPath($0, for: tab) }
        )) {
            Group {
                switch tab {
                case .feed: FeedView()
                case .boards: BoardsView()
                case .saved: SavedView()
                case .settings: SettingsView()
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .board(let board): BoardNoticesView(board: board)
                case .notice(let ref): NoticeDetailView(ref: ref)
                case .pinned: PinnedView()
                case .subscriptions: SubscriptionsView()
                case .about: AboutView()
                }
            }
        }
    }
}

private struct TabRootView: View {
    @Environment(Navigator.self) private var navigator

    var body: some View {
        @Bindable var navigator = navigator
        TabView(selection: $navigator.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                TabStack(tab: tab)
                    .tabItem { Label(tab.title, systemImage: tab.symbol) }
                    .tag(tab)
            }
        }
    }
}

/// 펼친 듀오에서는 목록 칸과 본문 칸의 경계를 접히는 선에 맞춘다.
private struct SplitRootView: View {
    @Environment(Navigator.self) private var navigator

    var body: some View {
        GeometryReader { proxy in
            let layout = SplitLayout(proxy: proxy)
            HStack(spacing: 0) {
                rail
                    .frame(width: Theme.railWidth)
                Rectangle().fill(Theme.separator).frame(width: 1)
                TabStack(tab: navigator.selectedTab)
                    .id(navigator.selectedTab)
                    .frame(width: max(layout.listEnd - Theme.railWidth - 1, 280))
                if layout.foldWidth > 0 {
                    // 접히는 선 위에는 아무것도 두지 않는다.
                    Theme.background.frame(width: layout.foldWidth)
                } else {
                    Rectangle().fill(Theme.separator).frame(width: 1)
                }
                NavigationStack {
                    if let ref = navigator.selection {
                        NoticeDetailView(ref: ref)
                            .id(ref.id)
                    } else {
                        EmptyDetailView()
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Theme.background)
    }

    private var rail: some View {
        VStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                let isSelected = navigator.selectedTab == tab
                Button {
                    navigator.selectedTab = tab
                } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Theme.accentText : Theme.secondary)
                        .frame(width: 44, height: 44)
                        .background(isSelected ? Theme.accentBackground : .clear, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.top, 12)
        .frame(maxHeight: .infinity)
        .background(Theme.railBackground)
    }
}

/// 목록 칸이 끝나는 곳과 접히는 선의 폭.
private struct SplitLayout {
    let listEnd: CGFloat
    let foldWidth: CGFloat

    init(proxy: GeometryProxy) {
        if #available(iOS 27.1, *),
           let fold = proxy.reservedRegions(kind: .division).first(where: \.isActive) {
            listEnd = fold.frame.minX
            foldWidth = fold.frame.width
        } else {
            // 접히는 선이 없는 넓은 화면(아이패드 등)은 목록을 알맞은 폭으로 둔다.
            listEnd = min(max(proxy.size.width * 0.4, 360), 460)
            foldWidth = 0
        }
    }
}
