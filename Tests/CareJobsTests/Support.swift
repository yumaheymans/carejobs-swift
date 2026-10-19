import Foundation
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import CareJobs

/// What a stubbed request answers with.
enum StubReply {
    /// An HTTP response with a body.
    case http(status: Int, contentType: String, body: Data)
    /// A transport failure.
    case failure(URLError)
    /// Never answers (for cancellation tests).
    case hang
}

/// One request the stub saw.
struct SeenRequest {
    let method: String?
    let path: String
    let headers: [String: String]
    let body: Data

    /// The JSON-RPC message sent.
    var message: [String: Any] {
        (try? JSONSerialization.jsonObject(with: body) as? [String: Any]) ?? [:]
    }

    var method_: String { message["method"] as? String ?? "" }

    var params: [String: Any] { message["params"] as? [String: Any] ?? [:] }

    var toolName: String { params["name"] as? String ?? "" }

    var arguments: [String: Any] { params["arguments"] as? [String: Any] ?? [:] }
}

/// A `URLProtocol` that answers requests from a closure, keyed by host so tests
/// do not interfere with each other.
final class StubURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var replies: [String: (SeenRequest) -> StubReply] = [:]
    private static var seen: [String: [SeenRequest]] = [:]

    static func register(host: String, reply: @escaping (SeenRequest) -> StubReply) {
        lock.lock(); defer { lock.unlock() }
        replies[host] = reply
        seen[host] = []
    }

    static func requests(host: String) -> [SeenRequest] {
        lock.lock(); defer { lock.unlock() }
        return seen[host] ?? []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let host = request.url?.host ?? ""
        let seenRequest = SeenRequest(
            method: request.httpMethod,
            path: request.url?.path ?? "",
            headers: request.allHTTPHeaderFields ?? [:],
            body: StubURLProtocol.bodyData(of: request)
        )
        StubURLProtocol.lock.lock()
        StubURLProtocol.seen[host, default: []].append(seenRequest)
        let reply = StubURLProtocol.replies[host]
        StubURLProtocol.lock.unlock()

        switch reply?(seenRequest) ?? .failure(URLError(.cannotFindHost)) {
        case .http(let status, let contentType, let body):
            let response = HTTPURLResponse(
                url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": contentType]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case .hang:
            break
        }
    }

    override func stopLoading() {}

    private static func bodyData(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

/// A client wired to the stub.
struct StubbedClient {
    let client: CareJobsClient
    let host: String

    var requests: [SeenRequest] { StubURLProtocol.requests(host: host) }
    var last: SeenRequest { requests.last! }

    init(userAgent: String? = nil, reply: @escaping (SeenRequest) -> StubReply) {
        host = "stub-\(UUID().uuidString.lowercased()).test"
        StubURLProtocol.register(host: host, reply: reply)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        client = CareJobsClient(
            baseURL: URL(string: "http://\(host)")!,
            session: URLSession(configuration: configuration),
            userAgent: userAgent
        )
    }

    /// A client that answers every request with a recorded fixture.
    init(fixture: String, userAgent: String? = nil) {
        let body = Fixtures.data(fixture)
        self.init(userAgent: userAgent) { _ in .http(status: 200, contentType: "application/json", body: body) }
    }
}

enum Fixtures {
    static func data(_ name: String, file: StaticString = #filePath, line: UInt = #line) -> Data {
        guard let url = Bundle.module.url(forResource: "Fixtures", withExtension: nil) else {
            fatalError("the Fixtures resource directory is missing from the test bundle")
        }
        do {
            return try Data(contentsOf: url.appendingPathComponent(name))
        } catch {
            fatalError("cannot read fixture \(name): \(error)")
        }
    }

    /// The `result.structuredContent` JSON of a fixture.
    static func structuredContent(_ name: String) throws -> Any {
        let root = try JSONSerialization.jsonObject(with: data(name)) as? [String: Any]
        let result = root?["result"] as? [String: Any]
        return try XCTUnwrap(result?["structuredContent"], "\(name) has no structuredContent")
    }
}

/// Runs `body` and returns the `CareJobsError` it throws, failing the test otherwise.
func thrownError(_ body: () async throws -> some Any, file: StaticString = #filePath, line: UInt = #line) async -> CareJobsError? {
    do {
        _ = try await body()
        XCTFail("expected an error, got a result", file: file, line: line)
    } catch let error as CareJobsError {
        return error
    } catch {
        XCTFail("expected a CareJobsError, got \(error)", file: file, line: line)
    }
    return nil
}
