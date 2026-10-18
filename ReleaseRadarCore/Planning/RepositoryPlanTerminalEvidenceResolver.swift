import Foundation

public enum RepositoryPlanTerminalEvidenceResolver {
    public static func original(
        sourceRef: RepositoryPlanSourceReference,
        source: RepositoryPlanReconstructionSourceSnapshot
    ) throws -> RepositoryPlanTerminalEvidence {
        let projection = try RepositoryPlanProjectionValidator.validate(
            source.projectionBytes,
            against: source.capturedSourceManifest
        ).projection
        return .original(
            sourceRef: sourceRef,
            record: try resolve(sourceRef: sourceRef, projection: projection, source: source)
        )
    }

    static func requireExact(
        _ supplied: RepositoryPlanStateRecord,
        sourceRef: RepositoryPlanSourceReference,
        projection: RepositoryPlanProjection,
        source: RepositoryPlanReconstructionSourceSnapshot
    ) throws {
        let resolved = try resolve(
            sourceRef: sourceRef,
            projection: projection,
            source: source
        )
        guard try canonical(resolved) == canonical(supplied) else {
            throw RepositoryPlanReconstructionError.invalidPayload(
                "Original terminal evidence does not equal the exact captured referenced object."
            )
        }
    }

    private static func canonical(_ record: RepositoryPlanStateRecord) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(record)
    }

    private static func resolve(
        sourceRef: RepositoryPlanSourceReference,
        projection: RepositoryPlanProjection,
        source: RepositoryPlanReconstructionSourceSnapshot
    ) throws -> RepositoryPlanStateRecord {
        guard case let .document(documentID, locator) = sourceRef,
              let document = projection.documents.first(where: {
                  Data($0.id.utf8) == Data(documentID.utf8)
              }),
              let captured = source.capturedSourceManifest.sources.first(where: {
                  Data($0.artifactID.utf8) == Data(document.artifactID.utf8)
              }),
              captured.contentSHA256 == document.contentSHA256 else {
            throw RepositoryPlanReconstructionError.invalidPayload(
                "Original terminal evidence must reference one captured structured document."
            )
        }
        var scanner = StrictJSONDuplicateKeyScanner(bytes: captured.bytes)
        do { try scanner.validate() }
        catch {
            throw RepositoryPlanReconstructionError.invalidPayload(
                "The captured terminal-evidence document is not strict JSON."
            )
        }
        let root: Any
        do { root = try JSONSerialization.jsonObject(with: captured.bytes, options: [.fragmentsAllowed]) }
        catch {
            throw RepositoryPlanReconstructionError.invalidPayload(
                "The captured terminal-evidence document is not valid JSON."
            )
        }
        let object = try resolve(pointer: locator, in: root)
        guard JSONSerialization.isValidJSONObject(object),
              let dictionary = object as? [String: Any],
              Set(dictionary.keys) == [
                "format", "schemaVersion", "recordID", "repositoryID", "kind",
                "subject", "state", "occurredAt", "actorID", "phaseCompletion",
              ],
              let subject = dictionary["subject"] as? [String: Any]
        else {
            throw RepositoryPlanReconstructionError.invalidPayload(
                "The referenced terminal-state object has an unsupported shape."
            )
        }
        try validateSubjectKeys(subject, rawKind: dictionary["kind"] as? String)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do { return try decoder.decode(RepositoryPlanStateRecord.self, from: data) }
        catch {
            throw RepositoryPlanReconstructionError.invalidPayload(
                "The referenced terminal-state object is not state-record-v1."
            )
        }
    }

    private static func resolve(pointer: String, in root: Any) throws -> Any {
        guard pointer.isEmpty || pointer.hasPrefix("/") else {
            throw RepositoryPlanReconstructionError.invalidPayload(
                "Terminal evidence locators must be RFC 6901 JSON pointers."
            )
        }
        var value = root
        for component in pointer.split(separator: "/", omittingEmptySubsequences: false).dropFirst() {
            let token = try unescape(String(component))
            if let object = value as? [String: Any], let next = object[token] {
                value = next
            } else if let array = value as? [Any],
                      !token.isEmpty, token.allSatisfy(\.isNumber),
                      (token == "0" || !token.hasPrefix("0")),
                      let index = Int(token), array.indices.contains(index) {
                value = array[index]
            } else {
                throw RepositoryPlanReconstructionError.invalidPayload(
                    "The terminal evidence JSON pointer does not resolve exactly one object."
                )
            }
        }
        return value
    }

    private static func unescape(_ token: String) throws -> String {
        var result = ""
        var index = token.startIndex
        while index < token.endIndex {
            if token[index] != "~" {
                result.append(token[index])
                index = token.index(after: index)
                continue
            }
            let next = token.index(after: index)
            guard next < token.endIndex else {
                throw RepositoryPlanReconstructionError.invalidPayload("Invalid JSON pointer escape.")
            }
            switch token[next] {
            case "0": result.append("~")
            case "1": result.append("/")
            default:
                throw RepositoryPlanReconstructionError.invalidPayload("Invalid JSON pointer escape.")
            }
            index = token.index(after: next)
        }
        return result
    }

    private static func validateSubjectKeys(
        _ subject: [String: Any],
        rawKind: String?
    ) throws {
        let expected: Set<String> = switch rawKind {
        case RepositoryPlanStateRecord.Kind.taskCompletion.rawValue,
             RepositoryPlanStateRecord.Kind.taskSupersession.rawValue:
            ["ticketSourceID", "sourceID", "label", "title", "sortOrder"]
        case RepositoryPlanStateRecord.Kind.ticketAcceptance.rawValue:
            ["sourceID", "outcome", "phaseSourceID", "taskPlan"]
        case RepositoryPlanStateRecord.Kind.phaseLifecycle.rawValue:
            ["sourceID", "name"]
        case RepositoryPlanStateRecord.Kind.goalAcceptance.rawValue:
            ["phaseSourceID", "sourceGoalID"]
        default:
            []
        }
        guard !expected.isEmpty, Set(subject.keys) == expected else {
            throw RepositoryPlanReconstructionError.invalidPayload(
                "The terminal-state subject does not match its record kind."
            )
        }
    }
}
