import Foundation
import Testing
@testable import NoticeKit

/// 실제 게시판 제목으로 마감일 찾기를 확인한다.
struct NoticeDeadlineTests {
    func deadline(_ title: String, posted: String = "2026-10-29") -> String? {
        NoticeDeadline.find(in: title, postedOn: posted).map { String(format: "%04d-%02d-%02d", $0.year, $0.month, $0.day) }
    }

    @Test func tildeDates() {
        #expect(deadline("★ 2026학년도 2학기 (주)제일하이텍 장학생 선발 공고(~11/6금 15시)") == "2026-11-06")
        #expect(deadline("2026년 학부/대학원생을 위한 폭력예방교육(법정의무) 안내(~12/21까지)", posted: "2026-10-15") == "2026-12-21")
    }

    @Test func untilDates() {
        #expect(deadline("2026 컴퓨터학부 해외연수(중국) 신청 안내(11/6 오후 2시까지)", posted: "2026-10-26") == "2026-11-06")
        #expect(deadline("2026-겨울학기 현장실습학기제 학생 참여 안내(11/12 오후 2시까지)", posted: "2026-10-26") == "2026-11-12")
        #expect(deadline("2026학년도 2학기 국가장학금 신청자 가구원 동의 안내(2026.09.16.(수) 18:00 까지)", posted: "2026-09-07") == "2026-09-16")
        #expect(deadline("숭실대학교 가상융합대학원(메타버스문화콘텐츠학과) 2027학년도 전기 신입생 모집(2026.10.06(화) – 10.16(금) 16:00 마감)", posted: "2026-09-29") == "2026-10-16")
    }

    @Test func rangeEnd() {
        #expect(deadline("2026-2학기 학부 중간 강의평가 실시 안내(10.6~19까지)", posted: "2026-10-07") == "2026-10-19")
    }

    @Test func yearBoundary() {
        #expect(deadline("겨울방학 근로장학생 모집(~1/5)", posted: "2026-12-20") == "2027-01-05")
    }

    /// 행사 날짜나 기간 표기는 마감으로 보지 않는다.
    @Test func notDeadlines() {
        #expect(deadline("[숭실대학교 반도체산학기술센터] 2026학년도 2학기 제2차 숭실 반도체 콜로키움 개최") == nil)
        #expect(deadline("2026-2학기 논문계획서 및 졸업논문 제출 일정 안내") == nil)
        #expect(deadline("컴퓨터학부장 변경 안내(2026년 8월 1일 부)") == nil)
        #expect(deadline("2026학년도 2학기 학과근로장학생 모집 안내") == nil)
    }

    @Test func daysLeft() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 23)))
        #expect(NoticeDeadline(year: 2026, month: 11, day: 6).daysLeft(from: today) == 8)
        #expect(NoticeDeadline(year: 2026, month: 10, day: 29).daysLeft(from: today) == 0)
        #expect(NoticeDeadline(year: 2026, month: 10, day: 28).daysLeft(from: today) == -1)
    }
}
