import Foundation
import NoticeKit

// 게시판 전수점검 도구.
//
//   swift run board-check [--only id,id] [--engine html] [--config 경로] [--report 경로.md] [--json 경로.json] [--verbose]
//
// 게시판마다 목록 1·2페이지, 검색, 첫 글 상세를 실제로 불러 보고 결과를 표로 남긴다.
// 실패가 하나라도 있으면 종료 코드 1을 돌려준다.

struct Options {
    var only: Set<String>?
    var engine: String?
    var config: String?
    var report: String?
    var json: String?
    var verbose = false
    var concurrency = 8

    init(arguments: [String]) {
        var iterator = arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--only": only = iterator.next().map { Set($0.split(separator: ",").map(String.init)) }
            case "--engine": engine = iterator.next()
            case "--config": config = iterator.next()
            case "--report": report = iterator.next()
            case "--json": json = iterator.next()
            case "--concurrency": concurrency = iterator.next().flatMap(Int.init) ?? concurrency
            case "--verbose": verbose = true
            default:
                FileHandle.standardError.write(Data("알 수 없는 인자: \(argument)\n".utf8))
                exit(2)
            }
        }
    }
}

enum Status: String, Codable, Comparable {
    case pass = "통과"
    case warn = "경고"
    case fail = "실패"

    static func < (lhs: Status, rhs: Status) -> Bool {
        let order: [Status] = [.pass, .warn, .fail]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

struct BoardResult: Codable {
    let id: String
    let name: String
    let program: String
    var status: Status = .pass
    var page1Count = 0
    var datedCount = 0
    var latestDate: String?
    var page2: String = "-"
    var search: String = "-"
    var detail: String = "-"
    var attachments = 0
    var problems: [String] = []
    var sample: [String] = []

    mutating func flag(_ level: Status, _ message: String) {
        status = max(status, level)
        problems.append("[\(level.rawValue)] \(message)")
    }
}

func describe(_ error: Error) -> String {
    if let error = error as? NoticeError {
        switch error {
        case .http(let status, _): return "HTTP \(status)"
        case .invalidURL(let url): return "주소 오류 \(url)"
        case .decoding(let message): return message
        case .unsupported(let engine): return "미지원 엔진 \(engine)"
        case .noContent(let message): return message
        }
    }
    return error.localizedDescription
}

/// 제목에서 검색어로 쓸 만한 단어를 고른다. 특수문자를 뺀 가장 긴 단어.
func searchKeyword(from title: String) -> String? {
    let words = title
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { $0.count >= 2 && !$0.allSatisfy(\.isNumber) }
    return words.max { $0.count < $1.count }
}

func check(_ board: Board, client: NoticeClient) async -> BoardResult {
    var result = BoardResult(id: board.id, name: board.name, program: board.program.rawValue)
    let expect = board.expect

    let page1: [NoticeItem]
    do {
        page1 = try await client.list(board, page: 1)
    } catch {
        result.flag(.fail, "1페이지: \(describe(error))")
        return result
    }
    result.page1Count = page1.count
    result.datedCount = page1.filter { $0.date != nil }.count
    result.latestDate = page1.compactMap(\.date).max()
    result.sample = page1.prefix(3).map { "\($0.date ?? "날짜없음") \($0.isPinned ? "[고정] " : "")\($0.title)" }

    guard !page1.isEmpty else {
        result.flag(.fail, "1페이지 글이 0건")
        return result
    }
    // 제목 자리에 분류 이름 같은 것을 잘못 잡으면 같은 짧은 제목이 되풀이된다.
    let titles = page1.map(\.title)
    if page1.count >= 4, Set(titles).count * 10 < titles.count * 7 {
        result.flag(.fail, "제목 중복이 많음 (\(Set(titles).count)/\(titles.count)) — 제목 선택자 확인")
    }
    if titles.reduce(0, { $0 + $1.count }) < titles.count * 6 {
        result.flag(.fail, "제목이 지나치게 짧음 — 제목 선택자 확인")
    }
    if expect?.noDate != true, result.datedCount < page1.count / 2 {
        result.flag(.warn, "날짜를 읽은 글 \(result.datedCount)/\(page1.count)")
    }
    if expect?.dormant != true, expect?.noDate != true, let latest = result.latestDate, latest < "2026-01-01" {
        result.flag(.warn, "최근 글이 \(latest)")
    }

    // 2페이지: 1페이지에 없던 글이 나와야 넘김이 동작한다고 본다. 매 페이지 되풀이되는 고정 공지는 1페이지에 있으니 빠진다.
    if expect?.singlePage == true {
        result.page2 = "건너뜀"
    } else {
        do {
            let page2 = try await client.list(board, page: 2)
            let firstLinks = Set(page1.map(\.url))
            let fresh = page2.filter { !firstLinks.contains($0.url) }
            result.page2 = "\(page2.count)건 (새 글 \(fresh.count))"
            if fresh.isEmpty {
                result.flag(.warn, "2페이지에 새 글이 없음")
            }
        } catch {
            result.page2 = "오류"
            result.flag(.warn, "2페이지: \(describe(error))")
        }
    }

    // 검색: 1페이지 첫 일반 글 제목의 단어로 찾았을 때 그 글이 나와야 한다.
    let target = page1.first { !$0.isPinned } ?? page1[0]
    if !board.supportsSearch {
        result.search = "미지원"
    } else if let keyword = searchKeyword(from: target.title) {
        do {
            let found = try await client.list(board, page: 1, keyword: keyword)
            let hit = found.contains { $0.url == target.url || $0.title == target.title }
            result.search = "\(keyword) → \(found.count)건\(hit ? "" : " (대상 없음)")"
            if !hit {
                result.flag(.warn, "검색 '\(keyword)' 결과에 대상 글이 없음")
            }
        } catch {
            result.search = "오류"
            result.flag(.warn, "검색: \(describe(error))")
        }
    }

    do {
        let detail = try await client.detail(board, url: target.url)
        let length = detail.bodyText.count
        let images = detail.bodyHTML.components(separatedBy: "<img").count - 1
        result.detail = "본문 \(length)자" + (images > 0 ? " 그림 \(images)" : "")
        result.attachments = detail.attachments.count
        if length == 0 && detail.attachments.isEmpty && !detail.bodyHTML.contains("<img") {
            result.flag(.fail, "상세 본문이 비어 있음 \(target.url.absoluteString)")
        }
    } catch {
        result.detail = "오류"
        result.flag(.fail, "상세: \(describe(error)) \(target.url.absoluteString)")
    }
    return result
}

func markdown(_ results: [BoardResult], catalog: BoardCatalog) -> String {
    let counts = Dictionary(grouping: results, by: \.status).mapValues(\.count)
    var lines = [
        "# 게시판 점검 결과",
        "",
        "- 점검 시각: \(ISO8601DateFormatter().string(from: Date()))",
        "- 설정 버전: \(catalog.version) (\(catalog.updatedAt ?? "-"))",
        "- 통과 \(counts[.pass] ?? 0) · 경고 \(counts[.warn] ?? 0) · 실패 \(counts[.fail] ?? 0) / 전체 \(results.count)",
        "",
        "| 상태 | 아이디 | 이름 | 1페이지 | 날짜 | 최근 글 | 2페이지 | 검색 | 상세 | 첨부 | 문제 |",
        "|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    for r in results {
        let problems = r.problems.joined(separator: "<br>").replacingOccurrences(of: "|", with: "\\|")
        lines.append("| \(r.status.rawValue) | \(r.id) | \(r.name) | \(r.page1Count) | \(r.datedCount) | \(r.latestDate ?? "-") | \(r.page2) | \(r.search.replacingOccurrences(of: "|", with: "\\|")) | \(r.detail) | \(r.attachments) | \(problems) |")
    }
    lines.append("")
    lines.append("## 게시판별 첫 글")
    lines.append("")
    for r in results {
        lines.append("- **\(r.id)** \(r.name)")
        for sample in r.sample {
            lines.append("  - \(sample)")
        }
    }
    return lines.joined(separator: "\n") + "\n"
}

let options = Options(arguments: CommandLine.arguments)

let catalog: BoardCatalog
do {
    if let path = options.config {
        catalog = try BoardCatalog.decode(Data(contentsOf: URL(fileURLWithPath: path)))
    } else {
        catalog = try BoardCatalog.bundled()
    }
} catch {
    FileHandle.standardError.write(Data("설정을 읽지 못함: \(error)\n".utf8))
    exit(2)
}

let boards = catalog.boards.filter { board in
    (options.only?.contains(board.id) ?? true) && (options.engine.map { $0 == board.engine.rawValue } ?? true)
}
let configuration = URLSessionConfiguration.ephemeral
configuration.httpMaximumConnectionsPerHost = 2
let client = NoticeClient(catalog: catalog, fetcher: HTTPFetcher(session: URLSession(configuration: configuration)))

let results = await withTaskGroup(of: (Int, BoardResult).self) { group in
    var collected: [(Int, BoardResult)] = []
    var next = 0
    func enqueue() {
        guard next < boards.count else { return }
        let index = next
        let board = boards[index]
        next += 1
        group.addTask { (index, await check(board, client: client)) }
    }
    for _ in 0..<min(options.concurrency, boards.count) { enqueue() }
    for await item in group {
        collected.append(item)
        let r = item.1
        print("\(r.status.rawValue) \(r.id) — \(r.page1Count)건, 최근 \(r.latestDate ?? "-"), 2페이지 \(r.page2), 검색 \(r.search), \(r.detail)")
        if options.verbose || r.status != .pass {
            for problem in r.problems { print("    \(problem)") }
        }
        if options.verbose {
            for sample in r.sample { print("    · \(sample)") }
        }
        enqueue()
    }
    return collected.sorted { $0.0 < $1.0 }.map(\.1)
}

let counts = Dictionary(grouping: results, by: \.status).mapValues(\.count)
print("\n통과 \(counts[.pass] ?? 0) · 경고 \(counts[.warn] ?? 0) · 실패 \(counts[.fail] ?? 0) / 전체 \(results.count)")

if let path = options.report {
    try markdown(results, catalog: catalog).write(toFile: path, atomically: true, encoding: .utf8)
}
if let path = options.json {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(results).write(to: URL(fileURLWithPath: path))
}
exit((counts[.fail] ?? 0) > 0 ? 1 : 0)
