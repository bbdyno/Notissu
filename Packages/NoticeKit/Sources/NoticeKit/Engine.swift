import Foundation

/// 게시판을 읽는 방식.
///
/// HTML로 그려 주는 게시판은 모두 `html` 하나로 읽고, 차이는 선택자 묶음(`preset`)과
/// 게시판별 `selectors`로 맞춘다. 화면이 비어 있고 데이터를 따로 부르는 게시판만 엔진을 따로 둔다.
public enum Engine: String, Codable, Sendable, CaseIterable {
    case html
    /// 글로벌미디어·디지털미디어 (`/v1/board/?menuId=`)
    case nextApiV1
    /// AI전문대학원·중소기업대학원 (`/api/board/content/list`)
    case nextApiBoard
    /// 영화예술전공 (`/notice/notice_list?LastNoticeIndex=`)
    case film
    /// 가상융합대학원 (`/data/content.json`)
    case staticJSON
    /// 중앙도서관 (`/pyxis-api/.../bulletins`)
    case pyxis
}
