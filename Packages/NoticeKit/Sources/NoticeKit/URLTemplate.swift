import Foundation

enum URLTemplate {
    /// 주소 틀의 자리표시를 채운다.
    ///
    /// - `{page}`: 1부터 세는 페이지
    /// - `{page0}`: 0부터 세는 페이지
    /// - `{offset}`: `(page - 1) * pageSize`
    /// - `{keyword}`: 퍼센트 인코딩한 검색어. 게시판이 EUC-KR이면 EUC-KR로 인코딩한다.
    ///
    /// 틀에 섞인 한글 경로는 그대로 두면 `URL(string:)`이 인코딩한다.
    static func url(_ template: String, page: Int, pageSize: Int?, keyword: String?, encoding: String.Encoding = .utf8) throws -> URL {
        let page = max(page, 1)
        let filled = template
            .replacingOccurrences(of: "{page}", with: String(page))
            .replacingOccurrences(of: "{page0}", with: String(page - 1))
            .replacingOccurrences(of: "{offset}", with: String((page - 1) * (pageSize ?? 10)))
            .replacingOccurrences(of: "{keyword}", with: percentEncode(keyword ?? "", encoding: encoding))
        guard let url = URL(string: filled, encodingInvalidCharacters: true) else {
            throw NoticeError.invalidURL(filled)
        }
        return url
    }

    static func percentEncode(_ string: String, encoding: String.Encoding) -> String {
        guard !string.isEmpty else { return "" }
        if encoding == .utf8 {
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        }
        guard let data = string.data(using: encoding) else { return "" }
        return data.map { byte in
            let scalar = Unicode.Scalar(byte)
            if byte < 0x80, CharacterSet.alphanumerics.contains(scalar) {
                return String(Character(scalar))
            }
            return String(format: "%%%02X", byte)
        }.joined()
    }
}
