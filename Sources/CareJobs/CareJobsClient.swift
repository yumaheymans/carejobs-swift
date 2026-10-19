import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A client for the CareJobs.Now healthcare jobs API.
///
/// CareJobs.Now (<https://carejobs.now>) is a free US healthcare job board. Its
/// jobs are read daily from the career sites of US hospitals, health systems,
/// clinics and care employers, and the pay is what each posting states. The API
/// is a remote MCP server at <https://carejobs.now/api/mcp>: free, no key.
///
/// ```swift
/// let client = CareJobsClient()
/// let result = try await client.searchJobs(kind: .nurses, state: "TX", query: "ICU", limit: 5)
/// print(result.total, "jobs match")
/// for job in result.jobs {
///     print(job.title, "|", job.employer, "|", job.location ?? "remote", "|", job.url)
/// }
/// ```
///
/// Every result carries `text`, the plain-text summary the server writes. Every
/// error is a ``CareJobsError``. A client is a value type and safe to share
/// between tasks.
public struct CareJobsClient: Sendable {
    /// The CareJobs.Now site; the MCP endpoint is `/api/mcp` on it.
    public static let defaultBaseURL = URL(string: "https://carejobs.now")!

    /// The version of this package, sent in the default `User-Agent`.
    public static let version = "1.0.0"

    /// The host the client talks to.
    public let baseURL: URL
    /// The session requests go through.
    public let session: URLSession
    /// The `User-Agent` header.
    public let userAgent: String
    /// How long a request may go without receiving data before it fails with
    /// ``CareJobsError/timeout``. The server answers a query it has not seen
    /// before in up to about 20 seconds, so the default is generous.
    public let timeout: TimeInterval

    /// Creates a client.
    ///
    /// - Parameters:
    ///   - baseURL: The host to talk to. Defaults to <https://carejobs.now>.
    ///   - session: The session to use. Defaults to `URLSession.shared`.
    ///   - userAgent: The `User-Agent` header. Defaults to `carejobs-swift/<version>`.
    ///   - timeout: The request timeout in seconds. Defaults to 60.
    public init(
        baseURL: URL = CareJobsClient.defaultBaseURL,
        session: URLSession = .shared,
        userAgent: String? = nil,
        timeout: TimeInterval = 60
    ) {
        self.baseURL = baseURL
        self.session = session
        self.userAgent = userAgent ?? "carejobs-swift/\(CareJobsClient.version)"
        self.timeout = timeout
    }

    // MARK: Tools

    /// Searches the open healthcare jobs. Every filter is optional.
    ///
    /// - Parameters:
    ///   - query: Words every job must carry in its title, place, department or schedule, for example "ICU", "night" or "Houston".
    ///   - kind: Limits the search to one kind of job.
    ///   - employer: An employer, AI-training program or job board: its slug (for example "kaiser-permanente") or its name. ``employers(query:type:care:state:kind:limit:)`` finds the slugs.
    ///   - state: A US state: its two-letter code ("TX") or its name ("Texas").
    ///   - remote: Pass `true` for only remote (work-from-home) jobs.
    ///   - minHourlyUSD: Only jobs whose posted hourly ceiling reaches this many US dollars (1 to 1000).
    ///   - sort: The order of the results. The server's default is ``Sort/mixed``.
    ///   - limit: How many jobs to return (1 to 25, server default 10).
    public func searchJobs(
        query: String? = nil,
        kind: Kind? = nil,
        employer: String? = nil,
        state: String? = nil,
        remote: Bool? = nil,
        minHourlyUSD: Int? = nil,
        sort: Sort? = nil,
        limit: Int? = nil
    ) async throws -> SearchResult {
        var args: [String: JSONValue] = [:]
        args["query"] = query.map(JSONValue.string)
        args["kind"] = kind.map { .string($0.rawValue) }
        args["employer"] = employer.map(JSONValue.string)
        args["state"] = state.map(JSONValue.string)
        args["remote"] = remote.map(JSONValue.bool)
        args["min_hourly_usd"] = minHourlyUSD.map { .number(Double($0)) }
        args["sort"] = sort.map { .string($0.rawValue) }
        args["limit"] = limit.map { .number(Double($0)) }
        return try await callTool("search_healthcare_jobs", args)
    }

    /// Measures what healthcare jobs post as hourly pay.
    ///
    /// With no arguments it covers every kind of job; `kind` alone gives that
    /// job's pay and the employers posting the most for it; `employer` alone
    /// gives that employer's pay overall and by kind; both give that employer's
    /// pay for that job. See ``PayResult`` for which properties each answer sets.
    public func pay(kind: Kind? = nil, employer: String? = nil) async throws -> PayResult {
        var args: [String: JSONValue] = [:]
        args["kind"] = kind.map { .string($0.rawValue) }
        args["employer"] = employer.map(JSONValue.string)
        return try await callTool("get_healthcare_pay", args)
    }

    /// Reports how many healthcare jobs are open right now and how they split by
    /// kind of job, US state and employer.
    public func jobMarket() async throws -> JobMarket {
        try await callTool("get_healthcare_job_market", [:])
    }

    /// Reports open jobs by US state.
    ///
    /// With no state it covers every state; with a state, that state; with a
    /// state and a kind, that kind of job in that state. A kind without a state
    /// is an error the server reports. See ``StateResult`` for which properties
    /// each answer sets.
    ///
    /// - Parameters:
    ///   - state: A US state: its two-letter code or its name.
    ///   - kind: One kind of job; it needs a state.
    ///   - limit: How many of the newest jobs to return for a state (1 to 25, server default 10).
    public func jobsByState(state: String? = nil, kind: Kind? = nil, limit: Int? = nil) async throws -> StateResult {
        var args: [String: JSONValue] = [:]
        args["state"] = state.map(JSONValue.string)
        args["kind"] = kind.map { .string($0.rawValue) }
        args["limit"] = limit.map { .number(Double($0)) }
        return try await callTool("get_healthcare_jobs_by_state", args)
    }

    /// Lists the employers, AI-training programs and job boards whose jobs
    /// CareJobs.Now reads, most open jobs first. Every filter is optional.
    ///
    /// - Parameters:
    ///   - query: Part of the name, for example "Kaiser", "children" or "dialysis".
    ///   - type: Employers (the default), AI-training programs or job boards.
    ///   - care: A kind of care.
    ///   - state: Employers with open jobs in this US state.
    ///   - kind: Employers with open jobs of this kind.
    ///   - limit: How many to return (1 to 100, server default 20).
    public func employers(
        query: String? = nil,
        type: EmployerType? = nil,
        care: Care? = nil,
        state: String? = nil,
        kind: Kind? = nil,
        limit: Int? = nil
    ) async throws -> EmployerList {
        var args: [String: JSONValue] = [:]
        args["query"] = query.map(JSONValue.string)
        args["type"] = type.map { .string($0.rawValue) }
        args["care"] = care.map { .string($0.rawValue) }
        args["state"] = state.map(JSONValue.string)
        args["kind"] = kind.map { .string($0.rawValue) }
        args["limit"] = limit.map { .number(Double($0)) }
        return try await callTool("list_healthcare_employers", args)
    }

    /// Returns one employer, AI-training program or job board, by slug (for
    /// example "cvs-health") or by name.
    public func employer(slug: String) async throws -> Employer {
        try await callTool("get_healthcare_employer", ["employer": .string(slug)])
    }

    /// Returns the tools the server offers, with their input schemas.
    public func tools() async throws -> [Tool] {
        let data = try await rpc(method: "tools/list", params: [:], tool: nil)
        do {
            let envelope = try JSONDecoder().decode(RPCEnvelope<ToolsList>.self, from: data)
            guard let list = envelope.result else {
                throw CareJobsError.invalidResponse(message: "tools/list answered without a result")
            }
            return list.tools
        } catch let error as CareJobsError {
            throw error
        } catch {
            throw CareJobsError.decoding(tool: "tools/list", message: String(describing: error))
        }
    }

    // MARK: Plumbing

    /// Runs a tool, decodes its `structuredContent` into `T` and sets `text`.
    func callTool<T: Decodable & TextCarrying>(_ name: String, _ arguments: [String: JSONValue]) async throws -> T {
        let (text, data) = try await callToolData(name, arguments)
        do {
            var result = try JSONDecoder().decode(T.self, from: data)
            result.text = text
            return result
        } catch {
            throw CareJobsError.decoding(tool: name, message: String(describing: error))
        }
    }

    /// Runs a tool and returns the text summary and the raw `structuredContent` JSON.
    func callToolData(_ name: String, _ arguments: [String: JSONValue]) async throws -> (text: String, data: Data) {
        let params: [String: JSONValue] = ["name": .string(name), "arguments": .object(arguments)]
        let body = try await rpc(method: "tools/call", params: params, tool: name)

        let envelope: RPCEnvelope<ToolResult>
        do {
            envelope = try JSONDecoder().decode(RPCEnvelope<ToolResult>.self, from: body)
        } catch {
            throw CareJobsError.invalidResponse(message: "the tool answered with an unreadable result: \(error)")
        }
        guard let result = envelope.result else {
            throw CareJobsError.invalidResponse(message: "the answer held no result")
        }
        let text = result.content.filter { $0.type == "text" }.compactMap(\.text).joined(separator: "\n")
        if result.isError == true {
            throw CareJobsError.tool(name: name, message: text.isEmpty ? "\(name) failed" : text)
        }
        guard let structured = result.structuredContent, case .object = structured else {
            throw CareJobsError.invalidResponse(message: "\(name) answered without structured content")
        }
        let data: Data
        do {
            data = try JSONEncoder().encode(structured)
        } catch {
            throw CareJobsError.invalidResponse(message: "the structured content cannot be read: \(error)")
        }
        return (text, data)
    }

    /// Sends one JSON-RPC request and returns the JSON of the matching message.
    private func rpc(method: String, params: [String: JSONValue], tool: String?) async throws -> Data {
        let requestID = 1
        let message: [String: JSONValue] = [
            "jsonrpc": .string("2.0"),
            "id": .number(Double(requestID)),
            "method": .string(method),
            "params": .object(params),
        ]
        var request = URLRequest(url: baseURL.appendingPathComponent("api/mcp"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        do {
            request.httpBody = try JSONEncoder().encode(JSONValue.object(message))
        } catch {
            throw CareJobsError.invalidResponse(message: "the arguments cannot be encoded as JSON: \(error)")
        }

        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse else {
            throw CareJobsError.invalidResponse(message: "the answer was not an HTTP response")
        }
        let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? ""

        guard (200...299).contains(http.statusCode) else {
            var detail = ""
            if let body = try? messageData(in: data, contentType: contentType, id: requestID),
               let envelope = try? JSONDecoder().decode(RPCEnvelope<JSONValue>.self, from: body),
               let rpcError = envelope.error, !rpcError.message.isEmpty {
                detail = rpcError.message
            } else {
                detail = String(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
            }
            if detail.isEmpty { detail = HTTPURLResponse.localizedString(forStatusCode: http.statusCode) }
            throw CareJobsError.http(status: http.statusCode, message: detail)
        }

        let body = try messageData(in: data, contentType: contentType, id: requestID)
        if let envelope = try? JSONDecoder().decode(RPCEnvelope<JSONValue>.self, from: body), let rpcError = envelope.error {
            throw CareJobsError.rpc(code: rpcError.code, message: rpcError.message.isEmpty ? "JSON-RPC error" : rpcError.message)
        }
        return body
    }

    /// Runs the request, mapping transport failures to ``CareJobsError``.
    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await Transport.data(for: request, session: session)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            switch error.code {
            case .cancelled: throw CancellationError()
            case .timedOut: throw CareJobsError.timeout
            default: throw CareJobsError.network(message: error.localizedDescription)
            }
        } catch {
            throw CareJobsError.network(message: error.localizedDescription)
        }
    }

    /// The JSON-RPC message out of a plain JSON body or a `text/event-stream` body.
    private func messageData(in body: Data, contentType: String, id: Int) throws -> Data {
        guard contentType.contains("text/event-stream") else {
            guard (try? JSONDecoder().decode(JSONValue.self, from: body)) != nil else {
                throw CareJobsError.invalidResponse(message: "the server did not answer with JSON")
            }
            return body
        }
        let text = String(decoding: body, as: UTF8.self).replacingOccurrences(of: "\r\n", with: "\n")
        var fallback: Data?
        for event in text.components(separatedBy: "\n\n") {
            let payload = event.split(separator: "\n", omittingEmptySubsequences: false)
                .compactMap { line -> String? in
                    guard line.hasPrefix("data:") else { return nil }
                    let rest = line.dropFirst(5)
                    return String(rest.hasPrefix(" ") ? rest.dropFirst() : rest)
                }
                .joined(separator: "\n")
            guard !payload.isEmpty, let data = payload.data(using: .utf8),
                  let envelope = try? JSONDecoder().decode(RPCEnvelope<JSONValue>.self, from: data)
            else { continue }
            if envelope.id == id { return data }
            if fallback == nil, envelope.result != nil || envelope.error != nil { fallback = data }
        }
        if let fallback { return fallback }
        throw CareJobsError.invalidResponse(message: "the event stream held no JSON-RPC answer")
    }
}

// MARK: - Wire types

private struct RPCErrorBody: Decodable {
    let code: Int
    let message: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(Int.self, forKey: .code) ?? 0
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
    }

    private enum CodingKeys: String, CodingKey { case code, message }
}

private struct RPCEnvelope<Result: Decodable>: Decodable {
    let id: Int?
    let result: Result?
    let error: RPCErrorBody?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decodeIfPresent(Int.self, forKey: .id)
        error = try? container.decodeIfPresent(RPCErrorBody.self, forKey: .error)
        result = error == nil ? try container.decodeIfPresent(Result.self, forKey: .result) : nil
    }

    private enum CodingKeys: String, CodingKey { case id, result, error }
}

private struct ToolResult: Decodable {
    struct Part: Decodable {
        let type: String?
        let text: String?
    }

    let content: [Part]
    let structuredContent: JSONValue?
    let isError: Bool?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decodeIfPresent([Part].self, forKey: .content) ?? []
        structuredContent = try container.decodeIfPresent(JSONValue.self, forKey: .structuredContent)
        isError = try container.decodeIfPresent(Bool.self, forKey: .isError)
    }

    private enum CodingKeys: String, CodingKey { case content, structuredContent, isError }
}

private struct ToolsList: Decodable {
    let tools: [Tool]
}

// MARK: - Transport

/// One HTTP round trip on `dataTask`, so the same code runs on Apple platforms
/// and on Linux (where `URLSession` lives in FoundationNetworking and has no
/// async `data(for:)` before Swift 6). Cancelling the task cancels the request.
private enum Transport {
    private final class TaskBox: @unchecked Sendable {
        private let lock = NSLock()
        private var task: URLSessionDataTask?
        private var cancelled = false

        func set(_ task: URLSessionDataTask) {
            lock.lock()
            self.task = task
            let shouldCancel = cancelled
            lock.unlock()
            if shouldCancel { task.cancel() }
        }

        func cancel() {
            lock.lock()
            cancelled = true
            let task = self.task
            lock.unlock()
            task?.cancel()
        }
    }

    static func data(for request: URLRequest, session: URLSession) async throws -> (Data, URLResponse) {
        let box = TaskBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = session.dataTask(with: request) { data, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let data, let response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                }
                box.set(task)
                task.resume()
            }
        } onCancel: {
            box.cancel()
        }
    }
}
