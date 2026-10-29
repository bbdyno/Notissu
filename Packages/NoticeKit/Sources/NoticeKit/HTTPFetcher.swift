import Foundation

/// 게시판 페이지를 받아 오는 부분. 점검 도구와 앱이 같은 규칙으로 받도록 한곳에 둔다.
public struct HTTPFetcher: Sendable {
    public let session: URLSession
    public let userAgent: String

    public init(session: URLSession = .shared,
                userAgent: String = "Mozilla/5.0 (iPhone; CPU iPhone OS 27_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.0 Mobile/15E148 Safari/604.1") {
        self.session = session
        self.userAgent = userAgent
    }

    public func data(from url: URL, accept: String? = nil) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("ko-KR,ko;q=0.9", forHTTPHeaderField: "Accept-Language")
        if let accept {
            request.setValue(accept, forHTTPHeaderField: "Accept")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NoticeError.http(status: -1, url: url.absoluteString)
        }
        guard (200..<400).contains(http.statusCode) else {
            throw NoticeError.http(status: http.statusCode, url: url.absoluteString)
        }
        return (data, http)
    }

    /// 문서를 글자로 받는다. 인코딩은 설정 → 응답 헤더 → `<meta charset>` → UTF-8 → EUC-KR 순으로 정한다.
    public func string(from url: URL, encoding: String? = nil) async throws -> (String, URL) {
        let (data, response) = try await data(from: url)
        let finalURL = response.url ?? url
        if let name = encoding ?? response.textEncodingName, let decoded = Self.decode(data, charset: name) {
            return (decoded, finalURL)
        }
        if let charset = Self.metaCharset(in: data), let decoded = Self.decode(data, charset: charset) {
            return (decoded, finalURL)
        }
        if let decoded = String(data: data, encoding: .utf8) {
            return (decoded, finalURL)
        }
        if let decoded = String(data: data, encoding: .eucKR) {
            return (decoded, finalURL)
        }
        throw NoticeError.decoding("문자 인코딩을 알 수 없음: \(url.absoluteString)")
    }

    public func json(from url: URL) async throws -> Any {
        let (data, _) = try await data(from: url, accept: "application/json")
        do {
            return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw NoticeError.decoding("JSON: \(url.absoluteString)")
        }
    }

    static func decode(_ data: Data, charset: String) -> String? {
        String(data: data, encoding: String.Encoding(charset: charset))
    }

    /// 문서 앞부분에서 `<meta charset>`이나 `content="...; charset=..."`를 찾는다.
    static func metaCharset(in data: Data) -> String? {
        let head = String(decoding: data.prefix(4096), as: UTF8.self)
        let pattern = #"charset\s*=\s*["']?([A-Za-z0-9_\-]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: head, range: NSRange(head.startIndex..., in: head)),
              let range = Range(match.range(at: 1), in: head) else {
            return nil
        }
        return String(head[range])
    }
}

extension String.Encoding {
    static let eucKR = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.EUC_KR.rawValue)))

    init(charset: String) {
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(charset as CFString)
        if cfEncoding == kCFStringEncodingInvalidId {
            self = .utf8
        } else {
            self = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
        }
    }
}
