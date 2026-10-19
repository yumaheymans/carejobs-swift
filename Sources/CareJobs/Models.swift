import Foundation

// Every result carries `text`: the plain-text summary the server writes for the
// answer, handy to show a person or to hand to a language model. It is filled
// by the client and is not part of the coded data. The other properties are the
// answer's data, named after the keys the API sends (snake_case on the wire,
// camelCase here).
//
// Where the API sends `null` for "none", the Swift property is `nil`. On the
// answers that come in several shapes (``PayResult``, ``StateResult``), a
// property is `nil` when it is not part of the shape of the question asked.

/// A result that carries the server's text summary.
protocol TextCarrying {
    var text: String { get set }
}

// MARK: - Shared pieces

/// Posted hourly pay in US dollars, measured from the hourly rates open jobs
/// state (before shift differentials and bonuses).
public struct PayStats: Codable, Sendable, Equatable {
    /// The median posted hourly rate.
    public let median: Double
    /// The 25th percentile of what jobs pay (the middle of each advertised range).
    public let typicalLow: Double
    /// The 90th-percentile advertised ceiling.
    public let typicalHigh: Double
    /// How many distinct posted hourly rates went in.
    public let rateSamples: Int
    /// How many employers posted them.
    public let employers: Int
    /// How many open jobs the measure covers.
    public let openJobs: Int
    /// How many of those jobs post no hourly rate.
    public let noRate: Int
    /// `true` only where at least three employers post a rate.
    public let marketRate: Bool

    enum CodingKeys: String, CodingKey {
        case median
        case typicalLow = "typical_low"
        case typicalHigh = "typical_high"
        case rateSamples = "rate_samples"
        case employers
        case openJobs = "open_jobs"
        case noRate = "no_rate"
        case marketRate = "market_rate"
    }
}

/// One open job as ``SearchResult`` and ``Employer`` return it.
public struct Job: Codable, Sendable, Equatable {
    public let title: String
    public let employer: String
    /// The job board the job was read through, when it is another employer's job.
    public let via: String?
    /// The label of the kind of job, for example "Nurses" or "Doctors".
    public let kind: String
    /// The posted pay as text (for example "$42.43-$86.19/hr"), or `nil` when
    /// the posting states none. For a posting with no rate the server may give
    /// the typical pay of its employer and kind instead, and then says in the
    /// text that it is not a rate the posting states.
    public let pay: String?
    /// The job's schedule tags, for example "Full-time".
    public let schedule: [String]
    /// The facility named in the posting, when it names one.
    public let facility: String?
    /// The place of the job, or `nil` for a placeless job.
    public let location: String?
    /// The ISO date (`YYYY-MM-DD`) the job was first listed.
    public let listed: String
    /// The job's page on CareJobs.Now, where the user applies.
    public let url: String
    /// The employer's page on CareJobs.Now, when it has one.
    public let employerPage: String?

    enum CodingKeys: String, CodingKey {
        case title, employer, via, kind, pay, schedule, facility, location, listed, url
        case employerPage = "employer_page"
    }
}

// MARK: - searchJobs

/// The posted pay across the jobs a search matches.
public struct SearchPay: Codable, Sendable, Equatable {
    public let typicalLow: Double
    public let typicalHigh: Double
    public let median: Double
    /// How many distinct posted hourly rates went in.
    public let rateSamples: Int
    /// How many matching jobs post an hourly rate.
    public let priced: Int
    /// How many jobs match.
    public let open: Int

    enum CodingKeys: String, CodingKey {
        case typicalLow = "typical_low"
        case typicalHigh = "typical_high"
        case median
        case rateSamples = "rate_samples"
        case priced, open
    }
}

/// The answer of ``CareJobsClient/searchJobs(query:kind:employer:state:remote:minHourlyUSD:sort:limit:)``.
public struct SearchResult: Codable, Sendable, Equatable, TextCarrying {
    /// How many open jobs match the filters (all of them, not only the ones in ``jobs``).
    public let total: Int
    /// The posted pay across all matching jobs, or `nil` when none post a rate.
    public let pay: SearchPay?
    /// The jobs returned, at most the limit.
    public let jobs: [Job]
    /// The same search on the CareJobs.Now site.
    public let more: String
    /// The server's plain-text summary.
    public var text: String = ""

    enum CodingKeys: String, CodingKey { case total, pay, jobs, more }
}

// MARK: - pay

/// The pay of the 25th percentile to the 90th, board wide: the figures across
/// every open job (they carry no market-rate flag).
public struct BoardPay: Codable, Sendable, Equatable {
    public let median: Double
    public let typicalLow: Double
    public let typicalHigh: Double
    public let rateSamples: Int
    public let employers: Int
    public let openJobs: Int
    public let noRate: Int

    enum CodingKeys: String, CodingKey {
        case median
        case typicalLow = "typical_low"
        case typicalHigh = "typical_high"
        case rateSamples = "rate_samples"
        case employers
        case openJobs = "open_jobs"
        case noRate = "no_rate"
    }
}

/// The pay of one kind of job. ``label`` is set in the all-kinds answer and
/// `nil` in an employer's by-kind list.
public struct KindPay: Codable, Sendable, Equatable {
    public let kind: Kind
    public let label: String?
    public let stats: PayStats

    enum CodingKeys: String, CodingKey { case kind, label }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(Kind.self, forKey: .kind)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        stats = try PayStats(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(label, forKey: .label)
        try stats.encode(to: encoder)
    }
}

/// The pay one employer posts, as listed in ``PayResult/bestPaying``.
public struct EmployerPay: Codable, Sendable, Equatable {
    public let slug: String
    public let name: String
    public let stats: PayStats

    enum CodingKeys: String, CodingKey { case slug, name }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        slug = try container.decode(String.self, forKey: .slug)
        name = try container.decode(String.self, forKey: .name)
        stats = try PayStats(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(slug, forKey: .slug)
        try container.encode(name, forKey: .name)
        try stats.encode(to: encoder)
    }
}

/// The answer of ``CareJobsClient/pay(kind:employer:)``. Its shape follows the
/// question, and only the properties of that shape are set:
///
/// - no arguments: ``asOf``, ``typicalPayDefinition``, ``board``, ``payByKind``, ``noMarketRate``
/// - `kind`: ``asOf``, ``kind``, ``openJobs``, ``pay``, ``bestPaying``
/// - `employer`: ``asOf``, ``employer``, ``pay``, ``payText``, ``byKind``
/// - `kind` and `employer`: ``asOf``, ``employer``, ``kind``, ``openJobs``, ``pay``
///
/// ``pay`` is `nil` when too few of the employer's open jobs post an hourly
/// rate to measure; ``payText`` then says how that employer posts pay (for
/// example weekly).
public struct PayResult: Codable, Sendable, Equatable, TextCarrying {
    /// The ISO date the figures were measured.
    public let asOf: String

    /// How ``PayStats/typicalLow`` and ``PayStats/typicalHigh`` are measured.
    public let typicalPayDefinition: String?
    /// The pay across every open job.
    public let board: BoardPay?
    /// The pay of every kind of job.
    public let payByKind: [KindPay]?
    /// The kinds without a market rate. The API sends an array whose entries
    /// have not appeared yet, so they are kept as ``JSONValue``.
    public let noMarketRate: [JSONValue]?

    /// The kind of job the answer is about.
    public let kind: Kind?
    /// The employer's slug.
    public let employer: String?
    /// How many open jobs of that kind (or employer and kind) there are.
    public let openJobs: Int?
    /// The measured pay, or `nil` when it cannot be measured.
    public let pay: PayStats?
    /// How an employer posts pay, when ``pay`` is `nil`.
    public let payText: String?
    /// The employers posting the most for the kind of job.
    public let bestPaying: [EmployerPay]?
    /// An employer's pay by kind of job.
    public let byKind: [KindPay]?

    /// The server's plain-text summary.
    public var text: String = ""

    enum CodingKeys: String, CodingKey {
        case asOf = "as_of"
        case typicalPayDefinition = "typical_pay_definition"
        case board
        case payByKind = "pay_by_kind"
        case noMarketRate = "no_market_rate"
        case kind, employer
        case openJobs = "open_jobs"
        case pay
        case payText = "pay_text"
        case bestPaying = "best_paying"
        case byKind = "by_kind"
    }
}

// MARK: - jobMarket

/// The open jobs of one kind of job.
public struct JobMarketKind: Codable, Sendable, Equatable {
    public let slug: Kind
    public let label: String
    public let openJobs: Int

    enum CodingKeys: String, CodingKey {
        case slug, label
        case openJobs = "open_jobs"
    }
}

/// The open jobs of one US state.
public struct JobMarketState: Codable, Sendable, Equatable {
    public let code: String
    public let name: String
    public let openJobs: Int
    public let url: String

    enum CodingKeys: String, CodingKey {
        case code, name
        case openJobs = "open_jobs"
        case url
    }
}

/// The open jobs of one employer, AI-training program or job board.
public struct JobMarketEmployer: Codable, Sendable, Equatable {
    public let slug: String
    public let name: String
    public let type: EmployerType
    public let openJobs: Int

    enum CodingKeys: String, CodingKey {
        case slug, name, type
        case openJobs = "open_jobs"
    }
}

/// The answer of ``CareJobsClient/jobMarket()``: how many jobs are open and how
/// they split by kind, state and employer.
public struct JobMarket: Codable, Sendable, Equatable, TextCarrying {
    /// How many healthcare jobs are open right now.
    public let openJobs: Int
    /// How many employers and job boards have one or more open jobs.
    public let sourcesLive: Int
    /// How many jobs were first listed in the last 7 days.
    public let newLast7d: Int
    /// How many jobs are listed per week, or `nil` while the server has no figure.
    public let newPerWeek: Double?
    /// The ISO 8601 timestamp (UTC) of the latest read of the career sites. ``updatedAt`` parses it.
    public let updated: String
    /// The open jobs of every kind of job.
    public let openByKind: [JobMarketKind]
    /// The open jobs of every US state.
    public let openByState: [JobMarketState]
    /// The open jobs of every employer, most first.
    public let openByEmployer: [JobMarketEmployer]
    /// The server's plain-text summary.
    public var text: String = ""

    enum CodingKeys: String, CodingKey {
        case openJobs = "open_jobs"
        case sourcesLive = "sources_live"
        case newLast7d = "new_last_7d"
        case newPerWeek = "new_per_week"
        case updated
        case openByKind = "open_by_kind"
        case openByState = "open_by_state"
        case openByEmployer = "open_by_employer"
    }

    /// ``updated`` as a `Date`, or `nil` if it is not a valid ISO 8601 timestamp.
    public var updatedAt: Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: updated) { return date }
        return ISO8601DateFormatter().date(from: updated)
    }
}

// MARK: - jobsByState

/// The open jobs of one kind of job inside a state answer. ``url`` is `nil`
/// where the API sends none.
public struct KindCount: Codable, Sendable, Equatable {
    public let kind: Kind
    public let label: String
    public let openJobs: Int
    public let url: String?

    enum CodingKeys: String, CodingKey {
        case kind, label
        case openJobs = "open_jobs"
        case url
    }
}

/// One state in the every-state answer.
public struct StateSummary: Codable, Sendable, Equatable {
    public let code: String
    public let name: String
    public let openJobs: Int
    public let employers: Int
    public let topKinds: [KindCount]
    public let url: String

    enum CodingKeys: String, CodingKey {
        case code, name
        case openJobs = "open_jobs"
        case employers
        case topKinds = "top_kinds"
        case url
    }
}

/// The hourly pay quartiles of one kind of job in a state.
public struct StatePay: Codable, Sendable, Equatable {
    /// Set in a state's by-kind list, `nil` in a state-and-kind answer.
    public let kind: Kind?
    /// The 25th percentile of the posted hourly rates.
    public let p25: Double
    public let median: Double
    /// The 75th percentile.
    public let p75: Double
    /// How many jobs post an hourly rate.
    public let jobsWithRate: Int
    /// How many employers posted them (state answer only).
    public let employers: Int?

    enum CodingKeys: String, CodingKey {
        case kind, p25, median, p75
        case jobsWithRate = "jobs_with_rate"
        case employers
    }
}

/// A town with open jobs.
public struct Town: Codable, Sendable, Equatable {
    /// The town's name.
    public let key: String
    public let jobs: Int
    /// The town's slug on CareJobs.Now.
    public let slug: String?
}

/// An employer hiring in a state.
public struct Hirer: Codable, Sendable, Equatable {
    /// The employer's slug.
    public let key: String
    public let jobs: Int
}

/// One of a state's newest jobs.
public struct StateJob: Codable, Sendable, Equatable {
    public let title: String
    public let employer: String
    /// The place of the job, for example "Dallas, TX".
    public let location: String
    /// The posted pay as text, or `nil` when the posting states none.
    public let pay: String?
    public let listed: String
    public let url: String

    enum CodingKeys: String, CodingKey {
        case title, employer
        case location = "where"
        case pay, listed, url
    }
}

/// The answer of ``CareJobsClient/jobsByState(state:kind:limit:)``. Its shape
/// follows the question, and only the properties of that shape are set:
///
/// - no state: ``states``
/// - a state: ``state``, ``name``, ``openJobs``, ``employers``, ``url``, ``byKind``,
///   ``payByKind``, ``towns``, ``hiring``, ``newest``
/// - a state and a kind: ``state``, ``kind``, ``openJobs``, ``url``, and when the
///   slice is big enough for a page of its own also ``employers``, ``pay``,
///   ``towns``, ``hiring`` and ``newest``
public struct StateResult: Codable, Sendable, Equatable, TextCarrying {
    /// Every US state with its open jobs (no state given).
    public let states: [StateSummary]?

    /// The two-letter state code.
    public let state: String?
    /// The state's name.
    public let name: String?
    /// The kind of job, in a state-and-kind answer.
    public let kind: Kind?
    /// The open jobs in the state (or of the kind in the state).
    public let openJobs: Int?
    /// How many employers have open jobs there.
    public let employers: Int?
    /// The page of the answer on CareJobs.Now.
    public let url: String?
    /// The state's open jobs by kind of job.
    public let byKind: [KindCount]?
    /// The hourly pay quartiles by kind of job in the state.
    public let payByKind: [StatePay]?
    /// The hourly pay quartiles of the kind in the state, or `nil` when no job
    /// posts a rate or the slice is too small.
    public let pay: StatePay?
    /// The towns with the most jobs.
    public let towns: [Town]?
    /// The employers with the most jobs.
    public let hiring: [Hirer]?
    /// The newest jobs, at most the limit.
    public let newest: [StateJob]?

    /// The server's plain-text summary.
    public var text: String = ""

    enum CodingKeys: String, CodingKey {
        case states, state, name, kind
        case openJobs = "open_jobs"
        case employers, url
        case byKind = "by_kind"
        case payByKind = "pay_by_kind"
        case pay, towns, hiring, newest
    }
}

// MARK: - employers, employer

/// One entry of the employer list.
public struct EmployerSummary: Codable, Sendable, Equatable {
    /// The identifier other calls take, for example `"cvs-health"`.
    public let slug: String
    public let name: String
    /// Whether it is an employer, an AI-training program or a job board.
    public let type: EmployerType
    /// The business model, for example "Pharmacy and retail health".
    public let model: String
    /// The label of the kind of care.
    public let care: String
    /// The headquarters, or `nil` when not known.
    public let hq: String?
    /// The two-letter codes of the states it hires in.
    public let states: [String]
    public let openJobs: Int
    /// The median of the hourly rates its open jobs post, or `nil` when too few post one.
    public let postedMedianHourly: Double?
    /// Its page on CareJobs.Now.
    public let url: String

    enum CodingKeys: String, CodingKey {
        case slug, name, type, model, care, hq, states
        case openJobs = "open_jobs"
        case postedMedianHourly = "posted_median_hourly"
        case url
    }
}

/// The answer of ``CareJobsClient/employers(query:type:care:state:kind:limit:)``.
public struct EmployerList: Codable, Sendable, Equatable, TextCarrying {
    /// How many entries match (all of them, not only those returned).
    public let total: Int
    /// The entries returned, most open jobs first.
    public let entries: [EmployerSummary]
    /// The server's plain-text summary.
    public var text: String = ""

    enum CodingKeys: String, CodingKey { case total, entries }
}

/// An employer's open jobs of one kind, with the pay they post.
public struct EmployerKind: Codable, Sendable, Equatable {
    public let kind: Kind
    public let label: String
    public let openJobs: Int
    /// The pay, or `nil` when too few of these jobs post an hourly rate.
    public let pay: PayStats?

    enum CodingKeys: String, CodingKey {
        case kind, label
        case openJobs = "open_jobs"
        case pay
    }
}

/// The answer of ``CareJobsClient/employer(slug:)``: one employer, AI-training
/// program or job board.
public struct Employer: Codable, Sendable, Equatable, TextCarrying {
    public let slug: String
    public let name: String
    public let type: EmployerType
    public let model: String
    public let care: String
    public let hq: String?
    public let states: [String]
    public let openJobs: Int
    /// Its open jobs by kind of job.
    public let openByKind: [EmployerKind]
    /// The pay its jobs post, or `nil` when too few post an hourly rate
    /// (``payText`` then says how it posts pay).
    public let pay: PayStats?
    public let payText: String?
    /// Its newest open jobs.
    public let newest: [Job]
    /// Its best-paid open jobs.
    public let bestPaid: [Job]
    /// Its page on CareJobs.Now.
    public let url: String
    /// Every open job of it on CareJobs.Now, or `nil` when it has none.
    public let jobsURL: String?
    /// Its own careers site, or `nil` when not known.
    public let careersURL: String?
    /// The server's plain-text summary.
    public var text: String = ""

    enum CodingKeys: String, CodingKey {
        case slug, name, type, model, care, hq, states
        case openJobs = "open_jobs"
        case openByKind = "open_by_kind"
        case pay
        case payText = "pay_text"
        case newest
        case bestPaid = "best_paid"
        case url
        case jobsURL = "jobs_url"
        case careersURL = "careers_url"
    }
}

// MARK: - tools

/// One tool as the server's `tools/list` answer describes it.
public struct Tool: Codable, Sendable, Equatable {
    public let name: String
    public let title: String?
    public let description: String?
    /// The tool's JSON Schema for its arguments.
    public let inputSchema: JSONValue
    /// The MCP behaviour hints of the tool, when the server sends them.
    public let annotations: ToolAnnotations?
}

/// The MCP behaviour hints of a tool. Every CareJobs.Now tool is read-only and
/// idempotent.
public struct ToolAnnotations: Codable, Sendable, Equatable {
    public let readOnlyHint: Bool?
    public let destructiveHint: Bool?
    public let idempotentHint: Bool?
    public let openWorldHint: Bool?
}
