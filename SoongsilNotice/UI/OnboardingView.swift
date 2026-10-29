//
//  OnboardingView.swift
//  Notissu
//
//  Copyright © 2026 Notissu. All rights reserved.
//

import SwiftUI
import NoticeKit

/// 처음 열었을 때 구독할 게시판을 고른다. 학교 공지는 미리 골라 둔다.
struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @State private var picked: [String] = []
    @State private var program: Board.Program = .undergraduate
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("소식에서 모아 볼 게시판을 골라 주세요. 나중에 게시판 탭에서 바꿀 수 있습니다.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                        .listRowSeparator(.hidden)
                    if query.isEmpty {
                        Picker("구분", selection: $program) {
                            Text("학부").tag(Board.Program.undergraduate)
                            Text("대학원").tag(Board.Program.graduate)
                            Text("학교").tag(Board.Program.campus)
                        }
                        .pickerStyle(.segmented)
                        .listRowSeparator(.hidden)
                    }
                }
                BoardSections(boards: visibleBoards) { board in
                    Button {
                        toggle(board)
                    } label: {
                        HStack {
                            Text(board.name).foregroundStyle(Theme.ink)
                            Spacer()
                            Image(systemName: picked.contains(board.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(picked.contains(board.id) ? Theme.accent : Theme.separator)
                        }
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(picked.contains(board.id) ? .isSelected : [])
                }
            }
            .listStyle(.plain)
            .navigationTitle("게시판 고르기")
            .searchable(text: $query, prompt: "학과나 게시판 이름")
            .safeAreaInset(edge: .bottom) {
                Button {
                    app.subscriptions = picked
                    app.isOnboarded = true
                    Task { await NotificationPermission.requestThenStartAds() }
                } label: {
                    Text(picked.isEmpty ? "게시판을 골라 주세요" : "\(picked.count)곳으로 시작하기")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accentText)
                .disabled(picked.isEmpty)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
            }
        }
        .onAppear {
            if picked.isEmpty, let school = app.catalog.board(legacyCode: 100) {
                picked = [school.id]
            }
        }
    }

    private var visibleBoards: [Board] {
        let keyword = query.trimmingCharacters(in: .whitespaces)
        if keyword.isEmpty {
            return app.catalog.boards.filter { $0.program == program }
        }
        return app.catalog.boards.filter { $0.name.localizedCaseInsensitiveContains(keyword) || $0.college.localizedCaseInsensitiveContains(keyword) }
    }

    private func toggle(_ board: Board) {
        if let index = picked.firstIndex(of: board.id) {
            picked.remove(at: index)
        } else {
            picked.append(board.id)
        }
    }
}
