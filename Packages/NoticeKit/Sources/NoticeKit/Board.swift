import Foundation

/// 공지 게시판 하나의 설정. `boards.json`에서 읽는다.
public struct Board: Codable, Sendable, Hashable, Identifiable {
    public enum Program: String, Codable, Sendable {
        case undergraduate
        case graduate
        case campus
    }

    public let id: String
    public let name: String
    public let college: String
    public let program: Program
    public let engine: Engine
    /// `html` 엔진이 쓰는 선택자 묶음 이름. `boards.json`의 `presets`에 있다.
    public let preset: String?

    /// 목록 주소 틀. `{page}`, `{page0}`, `{offset}`, `{keyword}` 자리표시를 쓴다.
    public let list: String
    /// 검색 주소 틀. 없으면 `list`에 `{keyword}`가 있을 때만 검색할 수 있다.
    public let search: String?
    /// 사람이 보는 게시판 화면 주소. 원문 열기에 쓴다.
    public let web: String?
    /// 응답 문자 인코딩. 지금은 `euc-kr`만 의미가 있다.
    public let encoding: String?
    /// `{offset}` 계산에 쓰는 한 페이지 글 수.
    public let pageSize: Int?
    /// 엔진 기본 선택자를 덮어쓴다.
    public let selectors: Selectors?
    /// 목록에서 꺼낸 링크 값을 상세 주소로 바꾸는 규칙.
    public let link: LinkRule?
    /// 상세 화면의 첨부 링크 값을 내려받기 주소로 바꾸는 규칙. 예: `javascript:download('a','1','2')`
    public let attachmentLink: LinkRule?
    /// 어댑터별 추가 값.
    public let options: [String: String]?
    /// 2.x 앱의 `DeptCode` 값. 저장된 내 학과를 옮길 때 쓴다.
    public let legacyCode: Int?
    /// 점검 도구가 경고를 덜 내도록 하는 표시. 예: 글이 한 페이지뿐인 게시판.
    public let expect: Expectation?

    public var supportsSearch: Bool {
        search != nil || list.contains("{keyword}")
    }
}

public extension Board {
    struct Selectors: Codable, Sendable, Hashable {
        public var row: String?
        public var title: String?
        /// 링크 요소. 없으면 제목 요소를 쓴다.
        public var link: String?
        /// 링크 값을 읽을 속성. 기본은 `href`.
        public var linkAttribute: String?
        /// 날짜 요소. 없으면 행 텍스트에서 날짜 모양을 찾는다.
        public var date: String?
        /// 행 안에 이 요소가 있으면 고정 공지로 본다.
        public var pinned: String?
        /// 행 안에 이 요소가 있으면 첨부가 있는 글로 본다.
        public var attachmentMark: String?
        /// 작성자나 등록 부서.
        public var author: String?
        public var detailTitle: String?
        public var detailBody: String?
        public var detailDate: String?
        /// 상세 화면의 첨부파일 링크 요소.
        public var attachment: String?

        public init(row: String? = nil, title: String? = nil, link: String? = nil, linkAttribute: String? = nil,
                    date: String? = nil, pinned: String? = nil, attachmentMark: String? = nil, author: String? = nil,
                    detailTitle: String? = nil, detailBody: String? = nil, detailDate: String? = nil,
                    attachment: String? = nil) {
            self.row = row
            self.title = title
            self.link = link
            self.linkAttribute = linkAttribute
            self.date = date
            self.pinned = pinned
            self.attachmentMark = attachmentMark
            self.author = author
            self.detailTitle = detailTitle
            self.detailBody = detailBody
            self.detailDate = detailDate
            self.attachment = attachment
        }

        /// `self`에 값이 있으면 그것을, 없으면 `base`의 값을 쓴다.
        func merged(over base: Selectors) -> Selectors {
            Selectors(row: row ?? base.row,
                      title: title ?? base.title,
                      link: link ?? base.link,
                      linkAttribute: linkAttribute ?? base.linkAttribute,
                      date: date ?? base.date,
                      pinned: pinned ?? base.pinned,
                      attachmentMark: attachmentMark ?? base.attachmentMark,
                      author: author ?? base.author,
                      detailTitle: detailTitle ?? base.detailTitle,
                      detailBody: detailBody ?? base.detailBody,
                      detailDate: detailDate ?? base.detailDate,
                      attachment: attachment ?? base.attachment)
        }
    }

    /// 링크 값에 `pattern`을 맞춰 캡처한 값을 `template`의 `$1`, `$2` 자리에 넣는다.
    struct LinkRule: Codable, Sendable, Hashable {
        public let pattern: String
        public let template: String
    }

    struct Expectation: Codable, Sendable, Hashable {
        /// 글이 한 페이지 분량뿐이라 2페이지 점검을 건너뛴다.
        public var singlePage: Bool?
        /// 게시판에 날짜 표기가 없다.
        public var noDate: Bool?
        /// 오래 글이 없어도 정상으로 본다.
        public var dormant: Bool?
    }
}
