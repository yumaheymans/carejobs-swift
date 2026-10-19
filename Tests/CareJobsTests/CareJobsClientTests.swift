import XCTest
@testable import CareJobs

final class CareJobsClientTests: XCTestCase {
    // MARK: Request shape

    func testRequestShape() async throws {
        let stub = StubbedClient(fixture: "search.json")
        _ = try await stub.client.searchJobs(kind: .nurses)
        let request = stub.last
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/mcp")
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        XCTAssertEqual(request.headers["Accept"], "application/json, text/event-stream")
        XCTAssertEqual(request.headers["User-Agent"], "carejobs-swift/\(CareJobsClient.version)")
        XCTAssertEqual(request.message["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(request.method_, "tools/call")
        XCTAssertEqual(request.toolName, "search_healthcare_jobs")
    }

    func testCustomUserAgentAndDefaults() async throws {
        let stub = StubbedClient(fixture: "market.json", userAgent: "my-app/2.0")
        _ = try await stub.client.jobMarket()
        XCTAssertEqual(stub.last.headers["User-Agent"], "my-app/2.0")

        let plain = CareJobsClient()
        XCTAssertEqual(plain.baseURL.absoluteString, "https://carejobs.now")
        XCTAssertEqual(plain.timeout, 60)
        XCTAssertEqual(plain.userAgent, "carejobs-swift/1.0.0")
    }

    func testArgumentsAreSentWithTheirWireNames() async throws {
        let search = StubbedClient(fixture: "search.json")
        _ = try await search.client.searchJobs(
            query: "ICU", kind: .nurses, employer: "hca", state: "TX", remote: true,
            minHourlyUSD: 60, sort: .highestPay, limit: 25
        )
        XCTAssertEqual(
            NSDictionary(dictionary: search.last.arguments),
            ["query": "ICU", "kind": "nurses", "employer": "hca", "state": "TX", "remote": true,
             "min_hourly_usd": 60, "sort": "highest_pay", "limit": 25] as NSDictionary
        )

        let empty = StubbedClient(fixture: "search.json")
        _ = try await empty.client.searchJobs()
        XCTAssertTrue(empty.last.arguments.isEmpty, "an unset filter must not be sent")

        let employers = StubbedClient(fixture: "employers.json")
        _ = try await employers.client.employers(
            query: "care", type: .aiProgram, care: .homeCare, state: "OH", kind: .caregivers, limit: 5
        )
        XCTAssertEqual(
            NSDictionary(dictionary: employers.last.arguments),
            ["query": "care", "type": "ai-program", "care": "home-care", "state": "OH",
             "kind": "caregivers", "limit": 5] as NSDictionary
        )

        let state = StubbedClient(fixture: "state_kind.json")
        _ = try await state.client.jobsByState(state: "OH", kind: .nursingAssistants, limit: 3)
        XCTAssertEqual(
            NSDictionary(dictionary: state.last.arguments),
            ["state": "OH", "kind": "nursing-assistants", "limit": 3] as NSDictionary
        )

        let pay = StubbedClient(fixture: "pay_employer_kind.json")
        _ = try await pay.client.pay(kind: .pharmacy, employer: "cvs-health")
        XCTAssertEqual(
            NSDictionary(dictionary: pay.last.arguments), ["kind": "pharmacy", "employer": "cvs-health"] as NSDictionary
        )

        let employer = StubbedClient(fixture: "employer.json")
        _ = try await employer.client.employer(slug: "cvs-health")
        XCTAssertEqual(employer.last.toolName, "get_healthcare_employer")
        XCTAssertEqual(NSDictionary(dictionary: employer.last.arguments), ["employer": "cvs-health"] as NSDictionary)
    }

    // MARK: searchJobs

    func testSearchJobs() async throws {
        let stub = StubbedClient(fixture: "search.json")
        let result = try await stub.client.searchJobs(kind: .nurses, state: "TX", sort: .highestPay, limit: 3)
        XCTAssertEqual(result.total, 6628)
        XCTAssertEqual(result.jobs.count, 3)
        let pay = try XCTUnwrap(result.pay)
        XCTAssertEqual(pay.median, 45)
        XCTAssertEqual(pay.typicalLow, 40)
        XCTAssertEqual(pay.typicalHigh, 65)
        XCTAssertEqual(pay.rateSamples, 918)
        XCTAssertEqual(pay.priced, 1055)
        XCTAssertEqual(pay.open, 6628)

        let first = result.jobs[0]
        XCTAssertEqual(first.employer, "The Helper Bees")
        XCTAssertEqual(first.pay, "$125/hr")
        XCTAssertEqual(first.kind, "Nurses")
        XCTAssertEqual(first.location, "Uvalde, TX")
        XCTAssertEqual(first.listed, "2026-10-06")
        XCTAssertEqual(first.schedule, ["Contract"])
        XCTAssertEqual(first.employerPage, "https://carejobs.now/employers/the-helper-bees")
        XCTAssertNil(first.via)
        XCTAssertNil(first.facility)
        XCTAssertEqual(result.jobs[1].pay, "$69.14\u{2013}$97.17/hr", "the escaped en dash must decode")
        XCTAssertTrue(result.text.hasPrefix("6,628 open healthcare jobs match"))
        XCTAssertTrue(result.more.hasPrefix("https://carejobs.now/?work=nurses"))
    }

    func testSearchJobsVariants() async throws {
        let empty = try await StubbedClient(fixture: "search_empty.json").client.searchJobs(query: "zzzqqqxx")
        XCTAssertEqual(empty.total, 0)
        XCTAssertNil(empty.pay)
        XCTAssertTrue(empty.jobs.isEmpty)
        XCTAssertTrue(empty.text.hasPrefix("No open healthcare jobs"))

        let via = try await StubbedClient(fixture: "search_via_and_nopay.json").client.searchJobs(minHourlyUSD: 90)
        XCTAssertEqual(via.jobs[0].via, "Adzuna")
        XCTAssertNil(via.jobs[0].employerPage)
        XCTAssertNil(via.jobs[1].via)
        XCTAssertEqual(via.jobs[1].employerPage, "https://carejobs.now/employers/btydental")

        let unpriced = try await StubbedClient(fixture: "search_unpriced.json").client.searchJobs()
        XCTAssertNil(unpriced.pay)
        XCTAssertNil(unpriced.jobs[1].pay, "pay null must be nil")
        XCTAssertTrue(try XCTUnwrap(unpriced.jobs[0].pay).contains("not a rate this posting states"))

        let ai = try await StubbedClient(fixture: "search_ai.json").client.searchJobs(kind: .aiTraining)
        XCTAssertEqual(ai.total, 173)
        XCTAssertEqual(ai.jobs[0].kind, "AI training")
        XCTAssertEqual(ai.jobs[1].location, "Remote")
    }

    // MARK: pay

    func testPayOverview() async throws {
        let result = try await StubbedClient(fixture: "pay_overview.json").client.pay()
        XCTAssertEqual(result.asOf, "2026-10-19")
        let board = try XCTUnwrap(result.board)
        XCTAssertEqual(board.median, 40)
        XCTAssertEqual(board.openJobs, 301667)
        XCTAssertEqual(board.noRate, 214164)
        let kinds = try XCTUnwrap(result.payByKind)
        XCTAssertEqual(kinds.count, 4)
        XCTAssertEqual(kinds[0].kind, .nurses)
        XCTAssertEqual(kinds[0].label, "Registered Nurses & LPNs")
        XCTAssertEqual(kinds[0].stats.median, 45)
        XCTAssertEqual(kinds[0].stats.employers, 515)
        XCTAssertTrue(kinds[0].stats.marketRate)
        XCTAssertEqual(result.noMarketRate, [])
        XCTAssertNil(result.pay)
        XCTAssertNil(result.bestPaying)
        XCTAssertTrue(result.text.hasPrefix("Healthcare pay by kind of job"))
    }

    func testPayByKind() async throws {
        let result = try await StubbedClient(fixture: "pay_kind.json").client.pay(kind: .nurses)
        XCTAssertEqual(result.kind, .nurses)
        XCTAssertEqual(result.openJobs, 97460)
        XCTAssertEqual(result.pay?.median, 45)
        XCTAssertEqual(result.pay?.noRate, 70317)
        let best = try XCTUnwrap(result.bestPaying)
        XCTAssertEqual(best.count, 4)
        XCTAssertEqual(best[0].slug, "the-helper-bees")
        XCTAssertEqual(best[0].stats.median, 125)
        XCTAssertFalse(best[0].stats.marketRate)
    }

    func testPayByEmployer() async throws {
        let result = try await StubbedClient(fixture: "pay_employer.json").client.pay(employer: "cvs-health")
        XCTAssertEqual(result.employer, "cvs-health")
        XCTAssertEqual(result.pay?.median, 30)
        XCTAssertNil(result.payText)
        let byKind = try XCTUnwrap(result.byKind)
        XCTAssertEqual(byKind.count, 4)
        XCTAssertEqual(byKind[0].kind, .pharmacy)
        XCTAssertNil(byKind[0].label)
    }

    func testPayByEmployerAndKind() async throws {
        let result = try await StubbedClient(fixture: "pay_employer_kind.json").client.pay(kind: .pharmacy, employer: "cvs-health")
        XCTAssertEqual(result.employer, "cvs-health")
        XCTAssertEqual(result.kind, .pharmacy)
        XCTAssertEqual(result.openJobs, 5129)
        XCTAssertEqual(result.pay?.median, 25)
    }

    func testPayThatCannotBeMeasured() async throws {
        let employer = try await StubbedClient(fixture: "pay_employer_unmeasured.json").client.pay(employer: "cross-country-healthcare")
        XCTAssertNil(employer.pay)
        XCTAssertEqual(employer.payText, "Posted on travel assignments, as weekly pay")
        XCTAssertEqual(employer.byKind?.count, 0)

        let both = try await StubbedClient(fixture: "pay_employer_kind_unmeasured.json")
            .client.pay(kind: .nurses, employer: "cross-country-healthcare")
        XCTAssertNil(both.pay)
        XCTAssertEqual(both.openJobs, 4032)
    }

    // MARK: jobMarket

    func testJobMarket() async throws {
        let stub = StubbedClient(fixture: "market.json")
        let result = try await stub.client.jobMarket()
        XCTAssertEqual(stub.last.toolName, "get_healthcare_job_market")
        XCTAssertTrue(stub.last.arguments.isEmpty)
        XCTAssertEqual(result.openJobs, 301667)
        XCTAssertEqual(result.sourcesLive, 1280)
        XCTAssertEqual(result.newLast7d, 41967)
        XCTAssertNil(result.newPerWeek)

        let updated = try XCTUnwrap(result.updatedAt)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: updated)
        XCTAssertEqual([parts.year, parts.month, parts.day, parts.hour, parts.minute], [2026, 10, 19, 6, 59])

        XCTAssertEqual(result.openByKind[0].slug, .nurses)
        XCTAssertEqual(result.openByKind[0].openJobs, 97460)
        XCTAssertEqual(result.openByState[0].code, "TX")
        XCTAssertEqual(result.openByState[0].openJobs, 19360)
        XCTAssertEqual(result.openByEmployer[0].slug, "adzuna")
        XCTAssertEqual(result.openByEmployer[0].type, .jobBoard)
        XCTAssertEqual(result.openByEmployer[0].openJobs, 31995)
    }

    // MARK: jobsByState

    func testEveryState() async throws {
        let result = try await StubbedClient(fixture: "states_overview.json").client.jobsByState()
        let states = try XCTUnwrap(result.states)
        XCTAssertEqual(states.count, 4)
        XCTAssertNil(result.state)
        XCTAssertEqual(states[0].code, "TX")
        XCTAssertEqual(states[0].openJobs, 11203)
        XCTAssertEqual(states[0].topKinds[0].kind, .nurses)
        XCTAssertEqual(states[0].topKinds[0].openJobs, 3970)
        XCTAssertNil(states[0].topKinds[0].url)
    }

    func testOneState() async throws {
        let result = try await StubbedClient(fixture: "state_detail.json").client.jobsByState(state: "OH", limit: 3)
        XCTAssertEqual(result.state, "OH")
        XCTAssertEqual(result.name, "Ohio")
        XCTAssertEqual(result.openJobs, 7399)
        XCTAssertEqual(result.employers, 148)
        XCTAssertEqual(result.byKind?.count, 16)
        XCTAssertEqual(result.payByKind?.count, 12)
        XCTAssertEqual(result.towns?.count, 40)
        XCTAssertEqual(result.hiring?.count, 12)
        XCTAssertEqual(result.newest?.count, 3)
        XCTAssertEqual(result.byKind?[0].kind, .nurses)
        XCTAssertEqual(result.byKind?[0].url, "https://carejobs.now/states/ohio/nurses")
        let pay = try XCTUnwrap(result.payByKind?[0])
        XCTAssertEqual([pay.p25, pay.median, pay.p75], [36, 38, 48])
        XCTAssertEqual(pay.jobsWithRate, 132)
        XCTAssertEqual(pay.employers, 19)
        XCTAssertEqual(result.towns?[0].key, "Columbus")
        XCTAssertEqual(result.towns?[0].slug, "columbus")
        XCTAssertEqual(result.hiring?[0].key, "cleveland-clinic")
        XCTAssertEqual(result.newest?[0].employer, "Legacy Healthcare Services")
        XCTAssertNil(result.newest?[0].pay)
        XCTAssertEqual(result.newest?[0].location, "Tiffin, Canton and 3 more, OH")
    }

    func testOneStateAndKind() async throws {
        let result = try await StubbedClient(fixture: "state_kind.json")
            .client.jobsByState(state: "OH", kind: .nursingAssistants, limit: 3)
        XCTAssertEqual(result.state, "OH")
        XCTAssertEqual(result.kind, .nursingAssistants)
        XCTAssertEqual(result.openJobs, 477)
        XCTAssertEqual(result.employers, 42)
        let pay = try XCTUnwrap(result.pay)
        XCTAssertEqual([pay.p25, pay.median, pay.p75], [19, 19, 21])
        XCTAssertEqual(pay.jobsWithRate, 23)
        XCTAssertNil(pay.kind)
        XCTAssertEqual(result.newest?.count, 3)
        XCTAssertEqual(result.towns?[0].key, "Cincinnati")
        XCTAssertEqual(result.hiring?[0].key, "communicare-health-services")
    }

    func testStateAndKindTooSmallForAPage() async throws {
        let result = try await StubbedClient(fixture: "state_kind_sparse.json").client.jobsByState(state: "WY", kind: .dental)
        XCTAssertEqual(result.openJobs, 2)
        XCTAssertNil(result.pay)
        XCTAssertNil(result.newest)
        XCTAssertNil(result.employers)
        XCTAssertTrue(result.text.contains("too few for a page"))
    }

    // MARK: employers, employer

    func testEmployers() async throws {
        let result = try await StubbedClient(fixture: "employers.json").client.employers(limit: 3)
        XCTAssertEqual(result.total, 2017)
        XCTAssertEqual(result.entries.count, 3)
        let first = result.entries[0]
        XCTAssertEqual(first.slug, "cross-country-healthcare")
        XCTAssertEqual(first.type, .employer)
        XCTAssertEqual(first.hq, "Boca Raton, FL")
        XCTAssertEqual(first.openJobs, 7457)
        XCTAssertEqual(first.states.count, 51)
        XCTAssertNil(first.postedMedianHourly)
        let second = result.entries[1]
        XCTAssertEqual(second.slug, "cvs-health")
        XCTAssertEqual(second.postedMedianHourly, 30)
        XCTAssertEqual(second.url, "https://carejobs.now/employers/cvs-health")
    }

    func testEmployersNoneAndAIPrograms() async throws {
        let none = try await StubbedClient(fixture: "employers_empty.json").client.employers(query: "zzzqq")
        XCTAssertEqual(none.total, 0)
        XCTAssertTrue(none.entries.isEmpty)

        let ai = try await StubbedClient(fixture: "employers_ai.json").client.employers(type: .aiProgram)
        XCTAssertEqual(ai.total, 12)
        XCTAssertEqual(ai.entries[0].slug, "mindrift")
        XCTAssertEqual(ai.entries[0].type, .aiProgram)
        XCTAssertNil(ai.entries[0].hq)
    }

    func testEmployer() async throws {
        let result = try await StubbedClient(fixture: "employer.json").client.employer(slug: "cvs-health")
        XCTAssertEqual(result.slug, "cvs-health")
        XCTAssertEqual(result.name, "CVS Health")
        XCTAssertEqual(result.type, .employer)
        XCTAssertEqual(result.hq, "Woonsocket, RI")
        XCTAssertEqual(result.openJobs, 5655)
        XCTAssertEqual(result.pay?.median, 30)
        XCTAssertNil(result.payText)
        XCTAssertEqual(result.jobsURL, "https://carejobs.now/employers/cvs-health/jobs")
        XCTAssertEqual(result.careersURL, "https://jobs.cvshealth.com")
        XCTAssertEqual(result.openByKind.count, 10)
        XCTAssertEqual(result.openByKind[0].kind, .pharmacy)
        XCTAssertNotNil(result.openByKind[0].pay)
        XCTAssertEqual(result.newest.count, 3)
        XCTAssertEqual(result.bestPaid.count, 3)
        XCTAssertTrue(result.text.contains("CVS Health"))
    }

    func testEmployerThatIsAJobBoardOrAnAIProgram() async throws {
        let board = try await StubbedClient(fixture: "employer_board.json").client.employer(slug: "Adzuna")
        XCTAssertEqual(board.type, .jobBoard)
        XCTAssertEqual(board.hq, "London, UK")
        XCTAssertNil(board.jobsURL)
        XCTAssertNil(board.careersURL)
        XCTAssertEqual(board.newest[0].via, "Adzuna")
        XCTAssertNil(board.newest[0].employerPage)

        let program = try await StubbedClient(fixture: "employer_ai.json").client.employer(slug: "transperfect-dataforce")
        XCTAssertEqual(program.type, .aiProgram)
        XCTAssertNil(program.hq)
        XCTAssertNil(program.careersURL)
        XCTAssertNil(program.newest[0].location)
    }

    // MARK: tools

    func testTools() async throws {
        let stub = StubbedClient(fixture: "tools_list.json")
        let tools = try await stub.client.tools()
        XCTAssertEqual(stub.last.method_, "tools/list")
        XCTAssertEqual(tools.map(\.name), [
            "search_healthcare_jobs", "get_healthcare_pay", "get_healthcare_job_market",
            "get_healthcare_jobs_by_state", "list_healthcare_employers", "get_healthcare_employer",
        ])
        let kinds = tools[0].inputSchema["properties"]?["kind"]?["enum"]?.strings
        XCTAssertEqual(kinds, Kind.allCases.map(\.rawValue), "the Kind cases differ from the recorded server enum")
    }

    // MARK: Kinds

    func testKinds() throws {
        let slugs = [
            "nurses", "nurse-practitioners", "physicians", "nursing-assistants", "caregivers", "therapy-rehab",
            "mental-health", "pharmacy", "imaging", "lab", "surgical-techs", "emts-paramedics", "medical-assistants",
            "dental", "admin", "allied-health", "ai-training",
        ]
        XCTAssertEqual(Kind.allCases.map(\.rawValue), slugs)
        XCTAssertEqual(Set(Kind.allCases).count, 17)
        for slug in slugs { XCTAssertEqual(Kind(rawValue: slug).rawValue, slug) }
        XCTAssertEqual(Kind(rawValue: "nursing-assistants"), .nursingAssistants)

        let decoded = try JSONDecoder().decode([Kind].self, from: Data(#"["nurses","plumbers"]"#.utf8))
        XCTAssertEqual(decoded, [.nurses, .unknown("plumbers")])
        XCTAssertEqual(String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self), #"["nurses","plumbers"]"#)
        XCTAssertFalse(Kind.allCases.contains(.unknown("plumbers")))
    }

    func testAnUnknownKindDoesNotBreakAnAnswer() async throws {
        let json = #"""
        {"jsonrpc":"2.0","id":1,"result":{"content":[{"type":"text","text":"ok"}],"structuredContent":
        {"open_jobs":5,"sources_live":1,"new_last_7d":0,"new_per_week":null,"updated":"2026-10-19T06:59:23.821262+00:00",
         "open_by_kind":[{"slug":"midwives","label":"Midwives","open_jobs":5}],
         "open_by_state":[],"open_by_employer":[{"slug":"x","name":"X","type":"co-op","open_jobs":5}]}}}
        """#
        let stub = StubbedClient { _ in .http(status: 200, contentType: "application/json", body: Data(json.utf8)) }
        let market = try await stub.client.jobMarket()
        XCTAssertEqual(market.openByKind[0].slug, .unknown("midwives"))
        XCTAssertEqual(market.openByEmployer[0].type, .unknown("co-op"))
    }

    // MARK: Errors

    func testToolError() async {
        let stub = StubbedClient(fixture: "error_tool.json")
        let error = await thrownError { try await stub.client.employer(slug: "no-such-employer-xyz") }
        XCTAssertEqual(error, .tool(
            name: "get_healthcare_employer",
            message: "Unknown employer 'no-such-employer-xyz'. list_healthcare_employers lists the employers and their slugs."
        ))
        XCTAssertTrue(error?.errorDescription?.contains("Unknown employer") == true)
    }

    func testInvalidKindIsAToolError() async {
        let stub = StubbedClient(fixture: "error_kind.json")
        let error = await thrownError { try await stub.client.searchJobs(kind: .unknown("bogus")) }
        guard case .tool(let name, let message)? = error else { return XCTFail("error = \(String(describing: error))") }
        XCTAssertEqual(name, "search_healthcare_jobs")
        XCTAssertTrue(message.hasPrefix("Unknown kind 'bogus'"))
    }

    func testRPCError() async {
        let stub = StubbedClient(fixture: "error_rpc.json")
        let error = await thrownError { try await stub.client.jobMarket() }
        XCTAssertEqual(error, .rpc(code: -32601, message: "Method not found: nope"))
    }

    func testHTTPErrors() async {
        let cases: [(status: Int, type: String, body: String, message: String)] = [
            (400, "application/json", #"{"jsonrpc":"2.0","id":null,"error":{"code":-32600,"message":"Invalid Request"}}"#, "Invalid Request"),
            (502, "text/plain", "Bad gateway from the edge", "Bad gateway from the edge"),
            (500, "text/html", String(repeating: "x", count: 500), String(repeating: "x", count: 200)),
        ]
        for testCase in cases {
            let stub = StubbedClient { _ in .http(status: testCase.status, contentType: testCase.type, body: Data(testCase.body.utf8)) }
            let error = await thrownError { try await stub.client.jobMarket() }
            XCTAssertEqual(error, .http(status: testCase.status, message: testCase.message))
        }
        let empty = StubbedClient { _ in .http(status: 503, contentType: "text/plain", body: Data()) }
        let error = await thrownError { try await empty.client.jobMarket() }
        guard case .http(let status, let message)? = error else { return XCTFail("error = \(String(describing: error))") }
        XCTAssertEqual(status, 503)
        XCTAssertFalse(message.isEmpty)
    }

    func testProtocolAndDecodingErrors() async {
        let invalid: [String: String] = [
            "not json": "<html>hello</html>",
            "no result": #"{"jsonrpc":"2.0","id":1}"#,
            "no structured content": #"{"jsonrpc":"2.0","id":1,"result":{"content":[{"type":"text","text":"hi"}]}}"#,
            "array structured content": #"{"jsonrpc":"2.0","id":1,"result":{"content":[],"structuredContent":[1,2]}}"#,
        ]
        for (name, body) in invalid {
            let stub = StubbedClient { _ in .http(status: 200, contentType: "application/json", body: Data(body.utf8)) }
            let error = await thrownError { try await stub.client.searchJobs() }
            guard case .invalidResponse? = error else { XCTFail("\(name): error = \(String(describing: error))"); continue }
        }

        let wrongType = #"{"jsonrpc":"2.0","id":1,"result":{"content":[],"structuredContent":{"total":"many"}}}"#
        let stub = StubbedClient { _ in .http(status: 200, contentType: "application/json", body: Data(wrongType.utf8)) }
        let error = await thrownError { try await stub.client.searchJobs() }
        guard case .decoding(let tool, _)? = error else { return XCTFail("error = \(String(describing: error))") }
        XCTAssertEqual(tool, "search_healthcare_jobs")
    }

    func testEventStreamAnswer() async throws {
        let answer = String(decoding: Fixtures.data("market.json"), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let stream = "event: message\r\ndata: {\"jsonrpc\":\"2.0\",\"method\":\"notifications/progress\",\"params\":{}}\r\n\r\n"
            + "event: message\r\ndata: \(answer)\r\n\r\n"
        let stub = StubbedClient { _ in .http(status: 200, contentType: "text/event-stream", body: Data(stream.utf8)) }
        let market = try await stub.client.jobMarket()
        XCTAssertEqual(market.openJobs, 301667)

        let empty = StubbedClient { _ in .http(status: 200, contentType: "text/event-stream", body: Data(": keep-alive\n\n".utf8)) }
        let error = await thrownError { try await empty.client.jobMarket() }
        guard case .invalidResponse? = error else { return XCTFail("error = \(String(describing: error))") }
    }

    func testTransportFailures() async {
        let timedOut = StubbedClient { _ in .failure(URLError(.timedOut)) }
        let timeoutError = await thrownError { try await timedOut.client.jobMarket() }
        XCTAssertEqual(timeoutError, .timeout)

        let offline = StubbedClient { _ in .failure(URLError(.notConnectedToInternet)) }
        let networkError = await thrownError { try await offline.client.jobMarket() }
        guard case .network(let message)? = networkError else { return XCTFail("error = \(String(describing: networkError))") }
        XCTAssertFalse(message.isEmpty)
    }

    func testCancellation() async {
        let stub = StubbedClient { _ in .hang }
        let task = Task { try await stub.client.jobMarket() }
        try? await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("a cancelled call must not return a result")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("expected CancellationError, got \(error)")
        }
    }

    func testConcurrentUse() async throws {
        let stub = StubbedClient(fixture: "market.json")
        try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<8 { group.addTask { try await stub.client.jobMarket().openJobs } }
            for try await openJobs in group { XCTAssertEqual(openJobs, 301667) }
        }
    }
}
