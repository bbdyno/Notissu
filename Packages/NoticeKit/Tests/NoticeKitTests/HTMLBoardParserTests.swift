import Foundation
import Testing
@testable import NoticeKit

/// 실제 게시판에서 저장한 HTML로 선택자 설정을 확인한다. 네트워크는 쓰지 않는다.
struct HTMLBoardParserTests {
    let catalog = try! BoardCatalog.bundled()

    func fixture(_ name: String) throws -> String {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "html", subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test func wordpressList() throws {
        let board = try #require(catalog.board(id: "korlan"))
        let base = try #require(URL(string: "https://korlan.ssu.ac.kr/학과사무실알림/공지사항/", encodingInvalidCharacters: true))
        let items = try HTMLBoardParser.list(html: fixture("wordpress_list"), baseURL: base,
                                             board: board, selectors: catalog.selectors(for: board))

        #expect(items.count == 20)
        let first = try #require(items.first)
        #expect(first.title == "2026-2학기 논문계획서 및 졸업논문 제출 일정 안내")
        #expect(first.date == "2026-09-08")
        #expect(first.isPinned)
        #expect(first.hasAttachment)
        #expect(first.url.absoluteString.hasSuffix("slug=1774"))
        #expect(items.contains { !$0.isPinned })
    }

    @Test func wordpressDetail() throws {
        let board = try #require(catalog.board(id: "korlan"))
        let url = try #require(URL(string: "https://korlan.ssu.ac.kr/?term_id&slug=1774"))
        let detail = try HTMLBoardParser.detail(html: fixture("wordpress_detail"), url: url, board: board,
                                                selectors: catalog.selectors(for: board))

        #expect(detail.title == "2026-2학기 논문계획서 및 졸업논문 제출 일정 안내")
        #expect(detail.date == "2026-09-08")
        #expect(detail.bodyText.hasPrefix("안녕하세요. 국어국문학과 사무실에서"))
        #expect(detail.attachments.count == 4)
        #expect(detail.attachments.first?.name == "졸업논문계획서양식학부-2-4.hwp")
    }

    @Test func wordpressCardList() throws {
        let board = try #require(catalog.board(id: "mgmt"))
        let base = try #require(URL(string: "https://mgmt.ssu.ac.kr/"))
        let items = try HTMLBoardParser.list(html: fixture("wordpress_card_list"), baseURL: base,
                                             board: board, selectors: catalog.selectors(for: board))

        let first = try #require(items.first)
        #expect(first.title == "2027학년도 숭실대학교 벤처경영학과(계약학과) 신,편입생 모집안내")
        #expect(first.date == "2026-10-08")
    }

    /// 분류 표시(장학, 학사 …)가 아니라 실제 제목을 읽어야 한다.
    @Test func schoolNoticeList() throws {
        let board = try #require(catalog.board(id: "scatch"))
        let base = try #require(URL(string: "https://scatch.ssu.ac.kr/"))
        let items = try HTMLBoardParser.list(html: fixture("scatch_list"), baseURL: base,
                                             board: board, selectors: catalog.selectors(for: board))

        let first = try #require(items.first)
        #expect(first.title == "[숭실대학교 반도체산학기술센터] 2026학년도 2학기 제2차 숭실 반도체 콜로키움 개최")
        #expect(first.date == "2026-10-29")
        #expect(first.author == "산학협력진흥팀")
        #expect(Set(items.map(\.title)).count == items.count)
    }

    /// 본문에 게시판의 제목·날짜·조회수 영역이 섞이지 않아야 한다.
    @Test func schoolNoticeDetail() throws {
        let board = try #require(catalog.board(id: "scatch"))
        let url = try #require(URL(string: "https://scatch.ssu.ac.kr/"))
        let detail = try HTMLBoardParser.detail(html: fixture("scatch_detail"), url: url, board: board,
                                                selectors: catalog.selectors(for: board))

        #expect(detail.title == "[숭실대학교 반도체산학기술센터] 2026학년도 2학기 제2차 숭실 반도체 콜로키움 개최")
        #expect(detail.date == "2026-10-29")
        #expect(detail.bodyText.hasPrefix("숭실 반도체 콜로키움(SOONGSIL SEMICONDUCTOR COLLOQUIUM)"))
        #expect(!detail.bodyText.contains("2026년 10월 29일"))
    }

    @Test func urlTemplate() throws {
        let url = try URLTemplate.url("https://a.ssu.ac.kr/공지/page/{page}/?keyword={keyword}&o={offset}&p0={page0}",
                                      page: 3, pageSize: 15, keyword: "장학 안내")
        #expect(url.absoluteString == "https://a.ssu.ac.kr/%EA%B3%B5%EC%A7%80/page/3/?keyword=%EC%9E%A5%ED%95%99%20%EC%95%88%EB%82%B4&o=30&p0=2")

        let eucKR = try URLTemplate.url("https://dorm/?Q={keyword}", page: 1, pageSize: nil, keyword: "공지", encoding: .eucKR)
        #expect(eucKR.absoluteString == "https://dorm/?Q=%B0%F8%C1%F6")
    }

    @Test func dateNormalize() {
        #expect(NoticeDate.normalize("2026.10.29") == "2026-10-29")
        #expect(NoticeDate.normalize("등록일 26-1-5 조회 30") == "2026-01-05")
        #expect(NoticeDate.normalize("2026년 9월 8일") == "2026-09-08")
        #expect(NoticeDate.normalize("조회수 5312") == nil)
        #expect(NoticeDate.normalize("08-27") == nil)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 29))!
        #expect(NoticeDate.normalize("08-27", allowMonthDay: true, today: today) == "2026-08-27")
        #expect(NoticeDate.normalize("12.30", allowMonthDay: true, today: today) == "2025-12-30")
    }
}
