/// A kind of healthcare job, the `kind` filter of the API.
///
/// The 17 slugs are the ones the live `tools/list` answer allows; a test
/// compares them with the server so drift is caught. A slug the server adds
/// later decodes as ``unknown(_:)`` instead of failing the whole answer, so
/// switch with a `default` branch.
public enum Kind: Hashable, Sendable, CaseIterable, RawRepresentable, Codable {
    /// Registered nurses and LPNs (`nurses`).
    case nurses
    /// NPs and PAs (`nurse-practitioners`).
    case nursePractitioners
    /// Doctors (`physicians`).
    case physicians
    /// CNAs and patient care techs (`nursing-assistants`).
    case nursingAssistants
    /// Caregivers and home health aides (`caregivers`).
    case caregivers
    /// Physical, occupational, speech and respiratory therapy (`therapy-rehab`).
    case therapyRehab
    /// Mental health and social work (`mental-health`).
    case mentalHealth
    /// Pharmacists and pharmacy techs (`pharmacy`).
    case pharmacy
    /// Radiology and imaging techs (`imaging`).
    case imaging
    /// Lab (`lab`).
    case lab
    /// Surgical techs (`surgical-techs`).
    case surgicalTechs
    /// EMS (`emts-paramedics`).
    case emtsParamedics
    /// Medical assistants (`medical-assistants`).
    case medicalAssistants
    /// Dental (`dental`).
    case dental
    /// Front desk and admin (`admin`).
    case admin
    /// Allied health (`allied-health`).
    case alliedHealth
    /// AI training for health professionals (`ai-training`).
    case aiTraining
    /// A slug this version of the package does not know yet.
    case unknown(String)

    /// The 17 known kinds, in the order the API documents them.
    public static let allCases: [Kind] = [
        .nurses, .nursePractitioners, .physicians, .nursingAssistants, .caregivers, .therapyRehab,
        .mentalHealth, .pharmacy, .imaging, .lab, .surgicalTechs, .emtsParamedics, .medicalAssistants,
        .dental, .admin, .alliedHealth, .aiTraining,
    ]

    /// The slug the API uses, for example `"nursing-assistants"`.
    public var rawValue: String {
        switch self {
        case .nurses: return "nurses"
        case .nursePractitioners: return "nurse-practitioners"
        case .physicians: return "physicians"
        case .nursingAssistants: return "nursing-assistants"
        case .caregivers: return "caregivers"
        case .therapyRehab: return "therapy-rehab"
        case .mentalHealth: return "mental-health"
        case .pharmacy: return "pharmacy"
        case .imaging: return "imaging"
        case .lab: return "lab"
        case .surgicalTechs: return "surgical-techs"
        case .emtsParamedics: return "emts-paramedics"
        case .medicalAssistants: return "medical-assistants"
        case .dental: return "dental"
        case .admin: return "admin"
        case .alliedHealth: return "allied-health"
        case .aiTraining: return "ai-training"
        case .unknown(let slug): return slug
        }
    }

    /// Reads a slug. An unknown slug becomes ``unknown(_:)``.
    public init(rawValue: String) {
        self = Kind.allCases.first { $0.rawValue == rawValue } ?? .unknown(rawValue)
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// The order of ``CareJobsClient/searchJobs(query:kind:employer:state:remote:minHourlyUSD:sort:limit:)`` results.
public enum Sort: String, Hashable, Sendable, CaseIterable, Codable {
    /// The board's order, employers interleaved (the server's default).
    case mixed
    /// Most recently listed first.
    case newest
    /// Highest posted pay first.
    case highestPay = "highest_pay"
}

/// What an employer list entry is.
///
/// A value the server adds later decodes as ``unknown(_:)``.
public enum EmployerType: Hashable, Sendable, CaseIterable, RawRepresentable, Codable {
    /// A hospital, health system, clinic or care company (`employer`).
    case employer
    /// A program paying health professionals for remote AI work (`ai-program`).
    case aiProgram
    /// A source of other employers' jobs (`job-board`).
    case jobBoard
    /// A type this version of the package does not know yet.
    case unknown(String)

    /// The three known types.
    public static let allCases: [EmployerType] = [.employer, .aiProgram, .jobBoard]

    /// The value the API uses, for example `"ai-program"`.
    public var rawValue: String {
        switch self {
        case .employer: return "employer"
        case .aiProgram: return "ai-program"
        case .jobBoard: return "job-board"
        case .unknown(let value): return value
        }
    }

    /// Reads a value. An unknown value becomes ``unknown(_:)``.
    public init(rawValue: String) {
        self = EmployerType.allCases.first { $0.rawValue == rawValue } ?? .unknown(rawValue)
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A kind of care, the `care` filter of ``CareJobsClient/employers(query:type:care:state:kind:limit:)``.
public enum Care: String, Hashable, Sendable, CaseIterable, Codable {
    case healthSystem = "health-system"
    case childrensHospital = "childrens-hospital"
    case outpatient
    case specialtyCare = "specialty-care"
    case behavioralHealth = "behavioral-health"
    case autismCare = "autism-care"
    case homeCare = "home-care"
    case seniorCare = "senior-care"
    case rehab
    case dental
    case pharmacyRetail = "pharmacy-retail"
    case kidneyCare = "kidney-care"
    case labsImaging = "labs-imaging"
    case telehealth
    case staffing
    case aiTraining = "ai-training"
    case jobBoards = "job-boards"
}
