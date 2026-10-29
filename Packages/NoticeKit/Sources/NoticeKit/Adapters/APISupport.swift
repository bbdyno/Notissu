import Foundation
import Kanna

// JSON API 엔진 어댑터가 함께 쓰는 부분.
//
// 주소 틀에는 `URLTemplate`의 자리표시 말고도 다음을 쓸 수 있다.
// - `{api}`: `options.api` 값. 바뀔 수 있는 API 주소를 게시판마다 한곳에만 적으려고 둔다.
// - `{id}`: 글 번호. `options.view`(사람이 보는 상세 화면)와 상세·첨부 API 틀에 쓴다.
// - `{cursor}`: 커서 방식 게시판의 마지막 글 번호.

extension Board {
    /// `{api}`와 `values`의 자리표시를 채운 뒤 `URLTemplate` 규칙을 적용한다.
    func apiURL(_ template: String, page: Int = 1, keyword: String? = nil, values: [String: String] = [:]) throws -> URL {
        var filled = template
        if filled.contains("{api}") {
            filled = filled.replacingOccurrences(of: "{api}", with: try option("api"))
        }
        for (key, value) in values {
            filled = filled.replacingOccurrences(of: "{\(key)}", with: Self.encodePathValue(value))
        }
        return try URLTemplate.url(filled, page: page, pageSize: pageSize, keyword: keyword, encoding: stringEncoding)
    }

    /// 검색어가 있으면 `search` 틀을, 없으면 `list` 틀을 쓴다. `listURL`에 `{api}` 처리를 더한 것.
    func apiListURL(page: Int, keyword: String?, values: [String: String] = [:]) throws -> URL {
        let keyword = Self.trimmedKeyword(keyword)
        let template = (keyword != nil ? search : nil) ?? list
        return try apiURL(template, page: page, keyword: keyword, values: values)
    }

    /// `options[key]` 틀이 있으면 그것을, 없으면 엔진 기본 틀을 채운다.
    func apiURL(option key: String, default template: String, values: [String: String]) throws -> URL {
        try apiURL(options?[key] ?? template, values: values)
    }

    /// 사람이 보는 상세 화면 주소. `options.view` 틀의 `{id}`에 글 번호를 넣는다.
    func viewURL(id: String) throws -> URL {
        try apiURL(option("view"), values: ["id": id])
    }

    /// `viewURL(id:)`로 만든 주소에서 글 번호를 되찾는다.
    func itemID(from url: URL) throws -> String {
        let template = try option("view")
        let pattern = "^" + NSRegularExpression.escapedPattern(for: template)
            .replacingOccurrences(of: "\\{id\\}", with: "([^/?&#]+)") + "$"
        let text = url.absoluteString
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            throw NoticeError.invalidURL("\(id): 글 번호를 찾지 못함 \(text)")
        }
        let raw = String(text[range])
        return raw.removingPercentEncoding ?? raw
    }

    static func trimmedKeyword(_ keyword: String?) -> String? {
        guard let trimmed = keyword?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// 글 번호 같은 값을 주소에 넣을 때 쓴다. 영문·숫자·`-._~`만 그대로 둔다.
    static func encodePathValue(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

extension HTTPFetcher {
    /// JSON 응답을 `Decodable`로 받는다. `method`는 GET이 아닌 조회 API(글로벌미디어 첨부 정보)에 쓴다.
    func decode<T: Decodable>(_ type: T.Type, from url: URL, method: String = "GET") async throws -> T {
        let data: Data
        if method == "GET" {
            data = try await self.data(from: url, accept: "application/json").0
        } else {
            var request = URLRequest(url: url, timeoutInterval: 20)
            request.httpMethod = method
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (body, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200..<300).contains(status) else {
                throw NoticeError.http(status: status, url: url.absoluteString)
            }
            data = body
        }
        return try JSONAPI.decode(type, from: data, url: url)
    }
}

enum JSONAPI {
    static func decode<T: Decodable>(_ type: T.Type, from data: Data, url: URL? = nil) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw NoticeError.decoding("JSON 해석 실패 \(url?.absoluteString ?? ""): \(error)")
        }
    }

    /// HTML 엔티티(`&middot;`, `&#39;` 등)를 한 번 푼다. 글 안의 `<`는 태그로 읽지 않는다.
    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        let guarded = text.replacingOccurrences(of: "<", with: "&lt;")
        guard let document = try? HTML(html: "<html><body>\(guarded)</body></html>", encoding: .utf8),
              let decoded = document.body?.text else {
            return text
        }
        return decoded
    }

    /// `&lt;p&gt;…`처럼 통째로 엔티티로 감싼 HTML을 푼다. 이미 HTML이면 그대로 둔다.
    static func unescapeHTMLSource(_ text: String) -> String {
        guard text.contains("&lt;"), !text.contains("<") else { return text }
        return decodeEntities(text)
    }

    static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// 검색 결과에 검색어와 상관없이 딸려 오는 고정 공지를 거른다.
    static func dropUnrelatedPinned(_ items: [NoticeItem], keyword: String?) -> [NoticeItem] {
        guard let keyword = Board.trimmedKeyword(keyword) else { return items }
        return items.filter { !$0.isPinned || $0.title.localizedCaseInsensitiveContains(keyword) }
    }
}

/// 숫자로도 글자로도 오는 JSON 값(글 번호 등).
struct FlexibleString: Decodable, Hashable, Sendable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = String(int)
        } else {
            value = try container.decode(String.self)
        }
    }
}
