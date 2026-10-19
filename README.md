# CareJobs (Swift)

Swift package for the [CareJobs.Now](https://carejobs.now) healthcare jobs API. Search open US healthcare jobs, see the pay employers post, and look up employers and states, with `async`/`await`.

- Free, no API key.
- Foundation only, no dependencies.
- iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, and Linux (`FoundationNetworking`).
- `Codable` and `Sendable` result types, a `Kind` enum with the 17 kinds of job, one `CareJobsError` type.
- The same API is a remote MCP server at <https://carejobs.now/api/mcp>, so any MCP client can use it too.

## Where the data comes from

CareJobs.Now is a free US healthcare job board. Its jobs are read daily from the career sites of US hospitals, health systems, clinics and care employers, and the pay is what each posting states (hourly rates before shift differentials and bonuses). Every job links to its page on CareJobs.Now, where the user applies. Data and docs: <https://carejobs.now/data> (CC BY 4.0, credit CareJobs.Now).

## Install

Swift Package Manager. In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yumaheymans/carejobs-swift.git", from: "1.0.0"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [.product(name: "CareJobs", package: "carejobs-swift")]
    ),
]
```

In Xcode: File, Add Package Dependencies, and enter `https://github.com/yumaheymans/carejobs-swift.git`.

## Quick start

```swift
import CareJobs

let client = CareJobsClient()

let result = try await client.searchJobs(query: "ICU", kind: .nurses, state: "TX", limit: 5)
print(result.total, "jobs match")
for job in result.jobs {
    print(job.title, "|", job.employer, "|", job.location ?? "remote", "|", job.url)
}

// Every result also carries the server's readable summary:
print(result.text)
```

## Client

```swift
let client = CareJobsClient(
    baseURL: URL(string: "https://carejobs.now")!,  // default
    session: .shared,                               // default
    userAgent: "my-app/1.0",                        // default "carejobs-swift/<version>"
    timeout: 60                                     // seconds, default 60
)
```

A `CareJobsClient` is a value type and safe to share between tasks. Cancelling the surrounding `Task` cancels the request and throws `CancellationError`.

| Method | What it answers | Result |
| --- | --- | --- |
| `searchJobs(query:kind:employer:state:remote:minHourlyUSD:sort:limit:)` | Open jobs, every filter optional | `SearchResult` |
| `pay(kind:employer:)` | Posted hourly pay: every kind, one kind, one employer, or both | `PayResult` |
| `jobMarket()` | How many jobs are open, by kind, state and employer | `JobMarket` |
| `jobsByState(state:kind:limit:)` | Every state, one state, or one kind of job in one state | `StateResult` |
| `employers(query:type:care:state:kind:limit:)` | The employers, AI-training programs and job boards the site reads | `EmployerList` |
| `employer(slug:)` | One employer by slug or name | `Employer` |
| `tools()` | The server's tools with their input schemas | `[Tool]` |

Every result has `text`, the plain-text summary the server writes. The other properties are the answer's data, named after the API's keys in camelCase (`open_jobs` is `openJobs`). Where the API sends `null`, the property is `nil`.

`pay` and `jobsByState` return one type for answers of different shapes. The documentation of `PayResult` and `StateResult` lists which properties each question sets; the others are `nil`. `PayResult.pay` is also `nil` when too few of an employer's jobs post an hourly rate to measure, and `payText` then says how the employer posts pay.

```swift
let pay = try await client.pay(kind: .nurses)
if let stats = pay.pay {
    print("median $\(stats.median)/hr, typical $\(stats.typicalLow) to $\(stats.typicalHigh)/hr")
}
for employer in pay.bestPaying ?? [] {
    print(employer.name, employer.stats.median)
}

let ohio = try await client.jobsByState(state: "OH", kind: .nursingAssistants)
print(ohio.openJobs ?? 0, ohio.newest?.first?.title ?? "none")
```

### Kinds

`Kind` has the 17 kinds of job: `.nurses`, `.nursePractitioners`, `.physicians`, `.nursingAssistants`, `.caregivers`, `.therapyRehab`, `.mentalHealth`, `.pharmacy`, `.imaging`, `.lab`, `.surgicalTechs`, `.emtsParamedics`, `.medicalAssistants`, `.dental`, `.admin`, `.alliedHealth`, `.aiTraining`. `Kind.allCases` lists them, and `rawValue` is the API's slug (`"nursing-assistants"`). A slug the server adds later decodes as `.unknown(slug)` instead of failing the answer, so use a `default` branch when you switch. `Sort`, `EmployerType` and `Care` are enums too.

### Errors

Every error is a `CareJobsError`:

```swift
do {
    let employer = try await client.employer(slug: "no-such-employer")
} catch let error as CareJobsError {
    switch error {
    case .tool(let name, let message): print(name, "said no:", message)  // unknown employer, invalid kind
    case .rpc(let code, let message): print("rpc", code, message)
    case .http(let status, let message): print("HTTP", status, message)
    case .timeout, .network: print("could not reach the API")
    case .invalidResponse, .decoding: print("unexpected answer")
    }
}
```

### Timeouts

The request timeout (the time the connection may stay silent) is 60 seconds by default. The server answers a query it has not seen before in up to about 20 seconds, and repeats of it in a fraction of a second.

## Tests

```sh
swift test                                          # offline, on recorded answers in Tests/CareJobsTests/Fixtures
CAREJOBS_LIVE=1 swift test --filter LiveTests       # the same questions against the real API
```

The unit tests replay real answers recorded from the live API (long lists are trimmed) through a `URLProtocol` stub. A round-trip test decodes each answer, encodes it again and compares it with the original JSON, so a field the types do not model is caught. The live test does the same against live answers and checks the `Kind` cases against the server's own list. Without `CAREJOBS_LIVE` the live tests are skipped.

## License

MIT. See [LICENSE](LICENSE).
