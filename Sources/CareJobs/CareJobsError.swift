import Foundation

/// Every error the client throws (apart from `CancellationError`, which is
/// rethrown as is when the surrounding task is cancelled).
public enum CareJobsError: Error, Sendable, Equatable {
    /// The server ran the tool and answered with an error, for example an
    /// unknown employer or an invalid kind. `message` is the server's text.
    case tool(name: String, message: String)
    /// A JSON-RPC error (unknown tool, malformed request).
    case rpc(code: Int, message: String)
    /// A non-2xx HTTP status.
    case http(status: Int, message: String)
    /// No answer before the request timed out.
    case timeout
    /// The request never completed (DNS, connection reset, no network).
    case network(message: String)
    /// The answer was not the shape the MCP protocol promises.
    case invalidResponse(message: String)
    /// The answer's data did not decode into the result type.
    case decoding(tool: String, message: String)
}

extension CareJobsError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .tool(let name, let message): return "CareJobs \(name): \(message)"
        case .rpc(let code, let message): return "CareJobs rpc error \(code): \(message)"
        case .http(let status, let message): return "CareJobs HTTP \(status): \(message)"
        case .timeout: return "CareJobs: no answer in time"
        case .network(let message): return "CareJobs network error: \(message)"
        case .invalidResponse(let message): return "CareJobs invalid response: \(message)"
        case .decoding(let tool, let message): return "CareJobs \(tool): could not decode the answer: \(message)"
        }
    }
}
