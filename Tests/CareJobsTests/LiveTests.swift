import XCTest
@testable import CareJobs

/// Runs against the real API, only when `CAREJOBS_LIVE` is set:
///
///     CAREJOBS_LIVE=1 swift test --filter LiveTests
///
/// A query the server has not seen before can take about 20 seconds.
final class LiveTests: XCTestCase {
    private var client: CareJobsClient!

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CAREJOBS_LIVE"] != nil,
            "set CAREJOBS_LIVE=1 to call the live API"
        )
        client = CareJobsClient()
    }

    /// Calls a tool live, decodes it, encodes it again and compares with what the server sent.
    private func assertRoundTrips<T: Codable & TextCarrying>(
        _ type: T.Type, tool: String, arguments: [String: JSONValue] = [:],
        file: StaticString = #filePath, line: UInt = #line
    ) async throws {
        let (text, data) = try await client.callToolData(tool, arguments)
        XCTAssertFalse(text.isEmpty, file: file, line: line)
        let original = try JSONSerialization.jsonObject(with: data)
        let value = try JSONDecoder().decode(T.self, from: data)
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
        let difference = RoundTripTests.difference(RoundTripTests.droppingNulls(original), encoded, path: "$")
        XCTAssertNil(difference, "\(tool) \(arguments): \(difference ?? "")", file: file, line: line)
    }

    func testSearchJobs() async throws {
        let result = try await client.searchJobs(query: "ICU", kind: .nurses, state: "TX", limit: 3)
        XCTAssertGreaterThan(result.total, 0)
        XCTAssertTrue((1...3).contains(result.jobs.count))
        XCTAssertFalse(result.text.isEmpty)
        XCTAssertTrue(result.jobs[0].url.hasPrefix("http"))
        try await assertRoundTrips(SearchResult.self, tool: "search_healthcare_jobs",
                                   arguments: ["kind": .string("nurses"), "state": .string("TX"), "limit": .number(3)])
        try await assertRoundTrips(SearchResult.self, tool: "search_healthcare_jobs", arguments: ["limit": .number(25)])
    }

    func testPay() async throws {
        let all = try await client.pay()
        XCTAssertNotNil(all.board)
        XCTAssertEqual(all.payByKind?.count, Kind.allCases.count)
        let nurses = try await client.pay(kind: .nurses)
        XCTAssertEqual(nurses.kind, .nurses)
        XCTAssertNotNil(nurses.pay)
        XCTAssertFalse(nurses.bestPaying?.isEmpty ?? true)
        let slug = try await client.employers(limit: 1).entries[0].slug
        let employer = try await client.pay(employer: slug)
        XCTAssertEqual(employer.employer, slug)

        try await assertRoundTrips(PayResult.self, tool: "get_healthcare_pay")
        try await assertRoundTrips(PayResult.self, tool: "get_healthcare_pay", arguments: ["kind": .string("nurses")])
        try await assertRoundTrips(PayResult.self, tool: "get_healthcare_pay", arguments: ["employer": .string(slug)])
        try await assertRoundTrips(PayResult.self, tool: "get_healthcare_pay",
                                   arguments: ["employer": .string(slug), "kind": .string("nurses")])
    }

    func testJobMarket() async throws {
        let market = try await client.jobMarket()
        XCTAssertGreaterThan(market.openJobs, 0)
        XCTAssertNotNil(market.updatedAt)
        XCTAssertEqual(market.openByKind.count, Kind.allCases.count)
        XCTAssertGreaterThanOrEqual(market.openByState.count, 50)
        try await assertRoundTrips(JobMarket.self, tool: "get_healthcare_job_market")
    }

    func testJobsByState() async throws {
        let all = try await client.jobsByState()
        XCTAssertGreaterThanOrEqual(all.states?.count ?? 0, 50)
        let ohio = try await client.jobsByState(state: "OH", limit: 3)
        XCTAssertEqual(ohio.name, "Ohio")
        XCTAssertFalse(ohio.newest?.isEmpty ?? true)
        let cnas = try await client.jobsByState(state: "OH", kind: .nursingAssistants, limit: 3)
        XCTAssertEqual(cnas.kind, .nursingAssistants)

        try await assertRoundTrips(StateResult.self, tool: "get_healthcare_jobs_by_state")
        try await assertRoundTrips(StateResult.self, tool: "get_healthcare_jobs_by_state",
                                   arguments: ["state": .string("OH"), "limit": .number(3)])
        try await assertRoundTrips(StateResult.self, tool: "get_healthcare_jobs_by_state",
                                   arguments: ["state": .string("OH"), "kind": .string("nursing-assistants"), "limit": .number(3)])
        try await assertRoundTrips(StateResult.self, tool: "get_healthcare_jobs_by_state",
                                   arguments: ["state": .string("WY"), "kind": .string("dental")])
    }

    func testEmployers() async throws {
        let list = try await client.employers(limit: 3)
        XCTAssertGreaterThan(list.total, 0)
        XCTAssertEqual(list.entries.count, 3)
        let employer = try await client.employer(slug: list.entries[0].slug)
        XCTAssertEqual(employer.slug, list.entries[0].slug)
        XCTAssertFalse(employer.newest.isEmpty)

        try await assertRoundTrips(EmployerList.self, tool: "list_healthcare_employers", arguments: ["limit": .number(3)])
        try await assertRoundTrips(EmployerList.self, tool: "list_healthcare_employers",
                                   arguments: ["type": .string("ai-program"), "limit": .number(3)])
        try await assertRoundTrips(Employer.self, tool: "get_healthcare_employer",
                                   arguments: ["employer": .string(list.entries[0].slug)])
        try await assertRoundTrips(Employer.self, tool: "get_healthcare_employer", arguments: ["employer": .string("Adzuna")])
    }

    func testToolErrorIsReported() async {
        let error = await thrownError { try await client.employer(slug: "no-such-employer-xyz") }
        guard case .tool(let name, _)? = error else { return XCTFail("error = \(String(describing: error))") }
        XCTAssertEqual(name, "get_healthcare_employer")
    }

    func testKindCasesMatchTheServer() async throws {
        let tools = try await client.tools()
        XCTAssertEqual(tools.count, 6, "the server has a tool this package does not know")
        for tool in tools {
            if let kinds = tool.inputSchema["properties"]?["kind"]?["enum"]?.strings {
                XCTAssertEqual(kinds, Kind.allCases.map(\.rawValue), "\(tool.name): the kind enum on the server differs from Kind")
            }
        }
    }
}
