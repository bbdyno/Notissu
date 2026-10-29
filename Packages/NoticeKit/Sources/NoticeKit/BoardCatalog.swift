import Foundation

/// `boards.json` 전체. 선택자 묶음과 게시판 목록을 담는다.
public struct BoardCatalog: Codable, Sendable {
    public let version: Int
    public let updatedAt: String?
    public let presets: [String: Board.Selectors]
    public let boards: [Board]

    public init(version: Int, updatedAt: String?, presets: [String: Board.Selectors], boards: [Board]) {
        self.version = version
        self.updatedAt = updatedAt
        self.presets = presets
        self.boards = boards
    }

    /// 패키지에 함께 들어 있는 기본 설정.
    public static func bundled() throws -> BoardCatalog {
        guard let url = Bundle.module.url(forResource: "boards", withExtension: "json") else {
            throw NoticeError.noContent("boards.json")
        }
        return try decode(Data(contentsOf: url))
    }

    public static func decode(_ data: Data) throws -> BoardCatalog {
        do {
            return try JSONDecoder().decode(BoardCatalog.self, from: data)
        } catch {
            throw NoticeError.decoding("boards.json: \(error)")
        }
    }

    public func board(id: String) -> Board? {
        boards.first { $0.id == id }
    }

    public func board(legacyCode: Int) -> Board? {
        boards.first { $0.legacyCode == legacyCode }
    }

    /// 게시판 설정과 선택자 묶음을 합친 최종 선택자.
    public func selectors(for board: Board) -> Board.Selectors {
        let base = board.preset.flatMap { presets[$0] } ?? Board.Selectors()
        return (board.selectors ?? Board.Selectors()).merged(over: base)
    }
}
