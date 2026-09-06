import Foundation

public struct ProjectID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct ProjectRegistration: Codable, Equatable, Hashable, Sendable {
    public let projectID: ProjectID
    public let registrationID: String
    public let requestGeneration: Int64

    public init(projectID: ProjectID, registrationID: String, requestGeneration: Int64) {
        self.projectID = projectID
        self.registrationID = registrationID
        self.requestGeneration = requestGeneration
    }
}
