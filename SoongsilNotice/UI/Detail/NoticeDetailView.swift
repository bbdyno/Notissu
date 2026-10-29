//
//  NoticeDetailView.swift
//  Notissu
//
//  Copyright © 2026 Notissu. All rights reserved.
//

import SwiftUI
import SwiftData
import QuickLook
import NoticeKit

/// 공지 본문. 제목·정보 표·본문·첨부 순서이고, 위쪽에 원문 열기·공유·저장이 있다.
struct NoticeDetailView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query private var savedMatches: [SavedNotice]

    let ref: NoticeRef

    @State private var detail: NoticeDetail?
    @State private var failed = false
    @State private var bodyHeight: CGFloat = 1
    @State private var downloading: URL?
    @State private var previewURL: URL?
    @State private var downloadFailed = false

    init(ref: NoticeRef) {
        self.ref = ref
        let url = ref.item.url.absoluteString
        _savedMatches = Query(filter: #Predicate<SavedNotice> { $0.url == url })
    }

    private var board: Board? { app.board(id: ref.boardID) }
    private var isSaved: Bool { !savedMatches.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(detail?.title?.nilIfEmpty ?? ref.item.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                infoTable

                if let detail {
                    if detail.bodyText.isEmpty && !detail.bodyHTML.contains("<img") {
                        Text("본문이 비어 있습니다. 첨부파일이나 원문을 확인해 주세요.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondary)
                    } else {
                        NoticeHTMLView(html: detail.bodyHTML, baseURL: detail.url, height: $bodyHeight)
                            .frame(height: bodyHeight)
                    }
                    if !detail.attachments.isEmpty {
                        attachments(detail.attachments)
                    }
                } else if failed {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("본문을 불러오지 못했습니다.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondary)
                        Link("원문에서 보기", destination: ref.item.url)
                            .font(.subheadline.weight(.semibold))
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Link(destination: ref.item.url) {
                    Image(systemName: "safari")
                }
                .accessibilityLabel("원문 열기")
                ShareLink(item: ref.item.url, subject: Text(ref.item.title)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("공유")
                Button(action: toggleSaved) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(isSaved ? "저장 취소" : "저장")
            }
        }
        .tint(Theme.accentText)
        .quickLookPreview($previewURL)
        .alert("첨부파일을 받지 못했습니다.", isPresented: $downloadFailed) {
            Button("원문에서 보기") { UIApplication.shared.open(ref.item.url) }
            Button("닫기", role: .cancel) {}
        }
        .task(id: ref.id) { await load() }
    }

    private var infoTable: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            GridRow {
                Text("게시판").foregroundStyle(Theme.secondary)
                Text(board?.name ?? "")
            }
            if let author = ref.item.author {
                GridRow {
                    Text("등록").foregroundStyle(Theme.secondary)
                    Text(author)
                }
            }
            if let date = detail?.date ?? ref.item.date {
                GridRow {
                    Text("날짜").foregroundStyle(Theme.secondary)
                    Text(NoticeFormat.fullDate(date))
                }
            }
            if let deadline = NoticeFormat.deadline(ref.item) {
                GridRow {
                    Text("마감").foregroundStyle(Theme.secondary)
                    Text(deadline).fontWeight(.bold).foregroundStyle(Theme.accentText)
                }
            }
        }
        .font(.subheadline)
        .foregroundStyle(Theme.ink)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Rectangle().fill(Theme.separator).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.separator).frame(height: 1) }
    }

    private func attachments(_ files: [NoticeAttachment]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("첨부파일 \(files.count)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.secondary)
                .padding(.bottom, 6)
            ForEach(files, id: \.url) { file in
                Button {
                    Task { await download(file) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: Self.symbol(for: file.name))
                            .foregroundStyle(Theme.accentText)
                            .frame(width: 22)
                            .accessibilityHidden(true)
                        Text(file.name)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if downloading == file.url {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(Theme.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(downloading != nil)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.separator).frame(height: 1) }
            }
        }
        .padding(.top, 8)
    }

    private func load() async {
        guard let board else {
            failed = true
            return
        }
        do {
            detail = try await app.client.detail(board, url: ref.item.url)
        } catch {
            failed = true
        }
    }

    /// 상세를 열 때 받은 세션 쿠키가 있어야 내려 주는 게시판이 있어 같은 공유 세션으로 받는다.
    private func download(_ file: NoticeAttachment) async {
        downloading = file.url
        defer { downloading = nil }
        do {
            var request = URLRequest(url: file.url)
            request.setValue(ref.item.url.absoluteString, forHTTPHeaderField: "Referer")
            let (temporary, response) = try await URLSession.shared.download(for: request)
            if let mime = (response as? HTTPURLResponse)?.mimeType, mime.hasPrefix("text/html") {
                throw URLError(.cannotDecodeContentData)
            }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("attachments", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let name = file.name.replacingOccurrences(of: "/", with: "_")
            let destination = folder.appendingPathComponent(name.isEmpty ? file.url.lastPathComponent : name)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: temporary, to: destination)
            previewURL = destination
        } catch {
            downloadFailed = true
        }
    }

    private func toggleSaved() {
        if let existing = savedMatches.first {
            context.delete(existing)
        } else {
            context.insert(SavedNotice(ref: ref, boardName: board?.name ?? ""))
        }
        try? context.save()
    }

    private static func symbol(for name: String) -> String {
        switch (name as NSString).pathExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "jpg", "jpeg", "png", "gif", "heic", "webp": return "photo"
        case "zip", "7z", "rar", "alz", "egg": return "archivebox"
        case "xls", "xlsx", "csv", "cell": return "tablecells"
        case "ppt", "pptx", "show": return "rectangle.on.rectangle"
        case "mp4", "mov", "avi": return "film"
        case "mp3", "m4a", "wav": return "waveform"
        default: return "doc.text"
        }
    }
}

/// 넓은 화면에서 아직 공지를 고르지 않았을 때 본문 칸.
struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.alignleft")
                .font(.largeTitle)
                .foregroundStyle(Theme.separator)
                .accessibilityHidden(true)
            Text("공지를 고르면 여기에 열립니다.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}
