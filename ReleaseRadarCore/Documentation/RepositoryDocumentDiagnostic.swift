import Foundation

public struct RepositoryDocumentDiagnostic: Codable, Equatable, Sendable {
    public static let formatIdentifier = "com.rekonlabs.release-radar.documentation-check-result"
    public static let currentSchemaVersion = 1

    public enum Status: String, Codable, Sendable {
        case passed
        case failed
    }

    public struct Checker: Codable, Equatable, Sendable {
        public let contractVersion: Int
        public let toolVersion: String?
        public let toolBuild: String?
        public let supportedCatalogVersions: [Int]

        private enum CodingKeys: String, CodingKey {
            case contractVersion, toolVersion, toolBuild, supportedCatalogVersions
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(contractVersion, forKey: .contractVersion)
            try container.encode(supportedCatalogVersions, forKey: .supportedCatalogVersions)
            if let toolVersion {
                try container.encode(toolVersion, forKey: .toolVersion)
            } else {
                try container.encodeNil(forKey: .toolVersion)
            }
            if let toolBuild {
                try container.encode(toolBuild, forKey: .toolBuild)
            } else {
                try container.encodeNil(forKey: .toolBuild)
            }
        }
    }

    public struct Target: Codable, Equatable, Sendable {
        public let repositoryID: String?
        public let catalogVersion: Int?
        public let catalogDigest: String?

        private enum CodingKeys: String, CodingKey {
            case repositoryID, catalogVersion, catalogDigest
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            if let repositoryID {
                try container.encode(repositoryID, forKey: .repositoryID)
            } else {
                try container.encodeNil(forKey: .repositoryID)
            }
            if let catalogVersion {
                try container.encode(catalogVersion, forKey: .catalogVersion)
            } else {
                try container.encodeNil(forKey: .catalogVersion)
            }
            if let catalogDigest {
                try container.encode(catalogDigest, forKey: .catalogDigest)
            } else {
                try container.encodeNil(forKey: .catalogDigest)
            }
        }
    }

    public struct Failure: Codable, Equatable, Sendable {
        public let code: String
        public let paths: [String]
    }

    public let format: String
    public let schemaVersion: Int
    public let checker: Checker
    public let target: Target
    public let status: Status
    public let error: Failure?

    private enum CodingKeys: String, CodingKey {
        case format, schemaVersion, checker, target, status, error
    }

    init(snapshot: RepositoryDocumentSnapshot?, status: Status, error: Failure?,
         toolVersion: String? = nil, toolBuild: String? = nil) {
        format = Self.formatIdentifier
        schemaVersion = Self.currentSchemaVersion
        checker = .init(
            contractVersion: 1,
            toolVersion: toolVersion,
            toolBuild: toolBuild,
            supportedCatalogVersions: [RepositoryDocumentContract.catalogVersion]
        )
        target = .init(
            repositoryID: snapshot?.catalog.repositoryID.lowercased(),
            catalogVersion: snapshot?.version,
            catalogDigest: snapshot?.digest
        )
        self.status = status
        self.error = error
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(format, forKey: .format)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(checker, forKey: .checker)
        try container.encode(target, forKey: .target)
        try container.encode(status, forKey: .status)
        if let error {
            try container.encode(error, forKey: .error)
        } else {
            try container.encodeNil(forKey: .error)
        }
    }
}
