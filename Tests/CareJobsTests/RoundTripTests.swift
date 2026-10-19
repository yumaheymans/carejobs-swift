import XCTest
@testable import CareJobs

/// Decodes every recorded answer, encodes the result again and compares it with
/// the original JSON (nulls dropped, as the Optional properties encode them). A
/// key a type does not model, or a wrong coding key, shows up as a difference.
final class RoundTripTests: XCTestCase {
    private func roundTrip<T: Codable>(_ type: T.Type, fixture: String) throws {
        let original = try Fixtures.structuredContent(fixture)
        let data = try JSONSerialization.data(withJSONObject: original)
        let value = try JSONDecoder().decode(T.self, from: data)
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
        let difference = Self.difference(Self.droppingNulls(original), encoded, path: "$")
        XCTAssertNil(difference, "\(fixture): \(difference ?? "")")
    }

    func testRecordedAnswersRoundTrip() throws {
        let searches = ["search", "search_empty", "search_via_and_nopay", "search_unpriced", "search_ai"]
        for name in searches { try roundTrip(SearchResult.self, fixture: "\(name).json") }
        let pays = ["pay_overview", "pay_kind", "pay_employer", "pay_employer_kind", "pay_employer_unmeasured", "pay_employer_kind_unmeasured"]
        for name in pays { try roundTrip(PayResult.self, fixture: "\(name).json") }
        try roundTrip(JobMarket.self, fixture: "market.json")
        for name in ["states_overview", "state_detail", "state_kind", "state_kind_sparse"] {
            try roundTrip(StateResult.self, fixture: "\(name).json")
        }
        for name in ["employers", "employers_empty", "employers_ai"] { try roundTrip(EmployerList.self, fixture: "\(name).json") }
        for name in ["employer", "employer_board", "employer_ai"] { try roundTrip(Employer.self, fixture: "\(name).json") }
    }

    func testToolsRoundTrip() throws {
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Fixtures.data("tools_list.json")) as? [String: Any])
        let result = try XCTUnwrap(root["result"] as? [String: Any])
        let tools = try XCTUnwrap(result["tools"])
        let data = try JSONSerialization.data(withJSONObject: tools)
        let decoded = try JSONDecoder().decode([Tool].self, from: data)
        XCTAssertEqual(decoded.count, 6)
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded))
        XCTAssertNil(Self.difference(Self.droppingNulls(tools), encoded, path: "$"))
    }

    // MARK: JSON comparison

    static func droppingNulls(_ value: Any) -> Any {
        if let object = value as? [String: Any] {
            return object.filter { !($0.value is NSNull) }.mapValues(droppingNulls)
        }
        if let array = value as? [Any] { return array.map(droppingNulls) }
        return value
    }

    /// The first difference between two parsed JSON values, or `nil` when equal.
    static func difference(_ a: Any, _ b: Any, path: String) -> String? {
        switch (a, b) {
        case let (a as [String: Any], b as [String: Any]):
            for key in Set(a.keys).union(b.keys).sorted() {
                switch (a[key], b[key]) {
                case (let x?, let y?):
                    if let found = difference(x, y, path: "\(path).\(key)") { return found }
                case (.some, nil): return "\(path).\(key) was lost"
                case (nil, .some): return "\(path).\(key) appeared"
                case (nil, nil): break
                }
            }
            return nil
        case let (a as [Any], b as [Any]):
            guard a.count == b.count else { return "\(path) has \(a.count) items, then \(b.count)" }
            for (index, pair) in zip(a, b).enumerated() {
                if let found = difference(pair.0, pair.1, path: "\(path)[\(index)]") { return found }
            }
            return nil
        case let (a as NSNumber, b as NSNumber):
            return a == b ? nil : "\(path): \(a) became \(b)"
        case let (a as String, b as String):
            return a == b ? nil : "\(path): \(a) became \(b)"
        default:
            return "\(path): \(type(of: a)) became \(type(of: b))"
        }
    }
}
