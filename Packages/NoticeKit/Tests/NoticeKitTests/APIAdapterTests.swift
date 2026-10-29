import Foundation
import Testing
@testable import NoticeKit

/// 실제 API에서 저장한 응답 일부로 JSON 엔진 어댑터의 해석을 확인한다. 네트워크는 쓰지 않는다.
struct APIAdapterTests {
    let catalog = try! BoardCatalog.bundled()

    func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    func board(_ id: String) throws -> Board {
        try #require(catalog.board(id: id))
    }

    @Test func viewURLRoundTrip() throws {
        let board = try board("metaverse")
        let url = try board.viewURL(id: "20260922-adm2027")
        #expect(url.absoluteString == "https://metaverse.ssu.ac.kr/notice.html?id=20260922-adm2027")
        #expect(try board.itemID(from: url) == "20260922-adm2027")
        #expect(throws: NoticeError.self) { try board.itemID(from: URL(string: "https://example.com/1")!) }
    }

    @Test func nextApiV1() throws {
        let board = try board("media")
        let response = try JSONAPI.decode(NextApiV1Parser.ListResponse.self, from: fixture("nextApiV1_list"))
        let items = try NextApiV1Parser.list(response, board: board)

        #expect(items.count == 4)
        let first = try #require(items.first)
        #expect(first.title == "2026-2학기 학부 중간 강의평가 실시 안내(10.6~19까지)")
        #expect(first.date == "2026-10-07")
        #expect(first.isPinned)
        #expect(first.author == "글미관리자")
        #expect(first.url.absoluteString == "https://media.ssu.ac.kr/board/notices/1812")
        #expect(items[3].title == "26-2학기 딥러닝(2150690601) 증원 안내")
        #expect(!items[3].isPinned)

        // 목록의 본문은 Lexical JSON을 한 번 더 글자로 감싼 모양이다.
        let html = try LexicalHTML.render(#require(response.data?.boards.first?.content))
        #expect(html.hasPrefix("<p>2026학년도 2학기 학부 중간 강의평가를"))

        let detailURL = try #require(URL(string: "https://media.ssu.ac.kr/board/notices/1781"))
        let post = try NextApiV1Parser.post(JSONAPI.decode(NextApiV1Parser.DetailResponse.self, from: fixture("nextApiV1_detail")),
                                            url: detailURL)
        #expect(post.attachments?.map(\.fileId) == [2313, 2314, 2315, 2318])
        let file = try #require(NextApiV1Parser.attachment(JSONAPI.decode(NextApiV1Parser.FileResponse.self,
                                                                             from: fixture("nextApiV1_file"))))
        #expect(file.name == "24학년도 입학자 기준 글로벌미디어학부 교과과정표.pdf")
        #expect(file.url.host == "globalmedia-bucket.s3.ap-northeast-2.amazonaws.com")

        let detail = try NextApiV1Parser.detail(post, url: detailURL, attachments: [file])
        #expect(detail.date == "2026-07-29")
        #expect(detail.bodyText.hasPrefix("안녕하세요. 학부사무실입니다."))
        #expect(detail.bodyHTML.contains("<li>21505597 웹프로그래밍및실습"))
    }

    @Test func lexicalFormatting() throws {
        let state = #"""
        {"editorState":{"root":{"children":[
          {"type":"heading","tag":"h2","children":[{"type":"text","text":"제목","format":1}]},
          {"type":"paragraph","format":"center","children":[
            {"type":"text","text":"a<b","format":0},{"type":"linebreak"},
            {"type":"link","url":"javascript:alert(1)","children":[{"type":"text","text":"x","format":0}]},
            {"type":"autolink","url":"https://ssu.ac.kr","children":[{"type":"text","text":"y","format":8}]}]},
          {"type":"paragraph","children":[]}
        ]}}}
        """#
        let html = try LexicalHTML.render(state)
        #expect(html == #"<h2><strong>제목</strong></h2><p style="text-align: center">a&lt;b<br>x<a href="https://ssu.ac.kr"><u>y</u></a></p><p><br></p>"#)
    }

    @Test func nextApiBoard() throws {
        let board = try board("aig")
        let response = try JSONAPI.decode(NextApiBoardParser.ListResponse.self, from: fixture("nextApiBoard_list"))
        let items = try NextApiBoardParser.list(response, board: board)

        #expect(items.count == 5)
        #expect(items[0].title == "2027학년도 신입학 수시 관련 고사건물 출입통제 안내")
        #expect(items[0].date == "2026-10-15")
        #expect(items[0].isPinned)
        #expect(!items[0].hasAttachment)
        #expect(items[1].hasAttachment)
        #expect(items[0].url.absoluteString == "https://aig.ssu.ac.kr/board/notice/15732")
        #expect(items[3].title == "신·편입생 등록금납부확인서 출력 안내")
        #expect(items[4].title == "숭실대 AI대학, EMNLP 2026에 논문 13편 발표")
        #expect(items[4].date == "2026-10-28")
        #expect(!items[4].isPinned)

        // 검색 결과에 딸려 오는 고정 공지 중 검색어가 없는 글은 거른다.
        let searched = JSONAPI.dropUnrelatedPinned(items, keyword: "등록금")
        #expect(searched.map(\.title) == ["2026학년도 2학기 등록금 납부 안내(재학생)", "신·편입생 등록금납부확인서 출력 안내",
                                          "숭실대 AI대학, EMNLP 2026에 논문 13편 발표"])

        let small = try self.board("small")
        let url = try small.viewURL(id: "13560")
        let detail = try NextApiBoardParser.detail(JSONAPI.decode(NextApiBoardParser.DetailResponse.self, from: fixture("nextApiBoard_detail")),
                                                   url: url, board: small)
        #expect(detail.title == "외국인 유학생 체류관련 안내(시간제취업 포함)")
        #expect(detail.date == "2026-09-03")
        #expect(detail.bodyHTML.hasPrefix(#"<p><span style="font-size:18px;">숭실대학교 중소기업대학원 교학팀입니다."#))
        #expect(detail.attachments.count == 3)
        #expect(detail.attachments.first?.name == "외국인유학생_체류안내 주요내용.pptx")
        #expect(detail.attachments.first?.url.absoluteString == "https://small.ssu.ac.kr/api/resource/download/7675")
    }

    @Test func film() throws {
        let board = try board("ssfilm")
        let items = try FilmParser.list(JSONAPI.decode(FilmParser.ListResponse.self, from: fixture("film_list")), board: board)

        #expect(items.count == 3)
        #expect(items[0].title == "u-SAINT ‘장학금 종류 및 신청 안내’ 메뉴 신설(학사과정)")
        #expect(items[0].date == "2026-10-27")
        #expect(!items[0].isPinned)
        #expect(items[0].url.absoluteString == "http://ssfilm.ssu.ac.kr/notice/index?NoticeIndex=823")
        #expect(items[1].hasAttachment)

        // 글이 없으면 `data_list`가 `false`로 온다.
        let empty = try JSONAPI.decode(FilmParser.ListResponse.self, from: fixture("film_empty"))
        #expect(empty.posts.isEmpty)
        #expect(empty.restCount == 0)

        let url = try board.viewURL(id: "822")
        let detail = try FilmParser.detail(JSONAPI.decode(FilmParser.DetailResponse.self, from: fixture("film_detail")),
                                           url: url, board: board)
        #expect(detail.date == "2026-10-27")
        #expect(detail.bodyHTML.hasPrefix(#"<p><img src="http://ssfilm.ssu.ac.kr/resource/upload/notice/202610271233_37277.png""#))
        #expect(detail.bodyText.contains("특별장학금을 시행하니"))
        let attachment = try #require(detail.attachments.first)
        #expect(attachment.name == "2026학년도-2학기-특별장학금-관련-서류.zip")
        let query = URLComponents(url: attachment.url, resolvingAgainstBaseURL: false)?.queryItems
        #expect(query?.first { $0.name == "filepath" }?.value == "/resource/upload/notice/202610271148_69174.zip")
    }

    @Test func staticJSON() throws {
        let board = try board("metaverse")
        let posts = try StaticJSONParser.posts(fixture("staticJSON_content"), board: board)
        let items = try StaticJSONParser.list(posts, page: 1, board: board)

        #expect(items.map(\.title) == ["2027학년도 전기 신입생 모집 안내", "2026년도 창의자율과제 2차 모집 안내",
                                       "가상융합대학원 홈페이지 개편 안내"])
        #expect(items.map(\.date) == ["2026-09-22", "2026-09-29", "2026-09-22"])
        #expect(items.map(\.isPinned) == [true, false, false])
        #expect(items.map(\.hasAttachment) == [false, true, false])
        #expect(try StaticJSONParser.list(posts, page: 2, board: board).isEmpty)

        let post = try #require(posts.first { $0.id == "20260929-creative2" })
        let detail = StaticJSONParser.detail(post, url: try board.viewURL(id: post.id))
        #expect(detail.bodyHTML.hasPrefix("<p>2026년도 창의자율과제 <b>2차 모집</b>을 안내합니다."))
        #expect(detail.attachments.first?.url.absoluteString == "https://metaverse.ssu.ac.kr/assets/posts/2026-creative-research-2nd.docx")
    }

    @Test func pyxis() throws {
        let board = try board("oasis")
        let items = try PyxisParser.list(JSONAPI.decode(PyxisParser.ListResponse.self, from: fixture("pyxis_list")), board: board)

        #expect(items.map(\.title) == ["11월 정보활용교육 신청 안내", "자연과학실 휴실로 인한 대출 및 출입불가(10/28~11/4)",
                                       "[CNKI AI] Free Trial(~'26.12)"])
        // 설정이 `date: lastUpdated`라 화면과 같이 수정 시각을 쓴다(CNKI 글은 27일 작성, 28일 수정).
        #expect(items.map(\.date) == ["2026-10-28", "2026-10-28", "2026-10-28"])
        #expect(items.map(\.hasAttachment) == [true, false, false])
        #expect(items[0].author == "채*미")
        #expect(items[0].url.absoluteString == "https://oasis.ssu.ac.kr/library-services/bulletin/notice/nuigpbsz1fy3k37l")

        let pinned = [NoticeItem(title: items[1].title, url: items[1].url, date: items[1].date, isPinned: true)]
        let merged = PyxisParser.merge(pinned: pinned, items: items)
        #expect(merged.map(\.isPinned) == [true, false, false])
        #expect(merged.count == 3)

        let detail = try PyxisParser.detail(JSONAPI.decode(PyxisParser.DetailResponse.self, from: fixture("pyxis_detail")),
                                            url: items[0].url, board: board)
        #expect(detail.title == "11월 정보활용교육 신청 안내")
        #expect(detail.bodyText.contains("11월 정보활용교육"))
        #expect(detail.attachments.first?.name == "download.png")
        #expect(detail.attachments.first?.url.absoluteString
                == "https://oasis.ssu.ac.kr/pyxis-api/attachments/BULLETIN/31dd4bce-e847-4b33-93a3-0347b951829b")
    }
}
