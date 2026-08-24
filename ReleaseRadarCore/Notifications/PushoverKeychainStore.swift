import Foundation
import Security

public protocol PushoverCredentialsProvider: Sendable {
    func loadCredentials() throws -> PushoverCredentials?
}

public struct StaticPushoverCredentialsProvider: PushoverCredentialsProvider, Sendable {
    public let credentials: PushoverCredentials?

    public init(credentials: PushoverCredentials?) {
        self.credentials = credentials
    }

    public func loadCredentials() throws -> PushoverCredentials? {
        credentials
    }
}

public final class PushoverKeychainStore: PushoverCredentialsProvider, @unchecked Sendable {
    public static let service = "com.rekonlabs.ReleaseRadar.pushover"

    public enum Account: String, CaseIterable, Sendable {
        case appToken = "app-token"
        case userKey = "user-key"
    }

    public init() {}

    public func save(_ credentials: PushoverCredentials) throws {
        do {
            try save(credentials.appToken, account: .appToken)
            try save(credentials.userKey, account: .userKey)
        } catch {
            try? deleteCredentials()
            throw error
        }
    }

    public func loadCredentials() throws -> PushoverCredentials? {
        let token = try load(account: .appToken)
        let user = try load(account: .userKey)
        switch (token, user) {
        case let (token?, user?): return PushoverCredentials(appToken: token, userKey: user)
        case (nil, nil): return nil
        default:
            try? deleteCredentials()
            return nil
        }
    }

    public func deleteCredentials() throws {
        for account in Account.allCases {
            let status = SecItemDelete(Self.itemAttributes(account: account) as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw PushoverKeychainError(status: status)
            }
        }
    }

    static func itemAttributes(account: Account) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
            kSecAttrSynchronizable as String: false,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String,
        ]
    }

    private func save(_ value: String, account: Account) throws {
        guard !value.isEmpty, value.utf8.count <= 1_024 else {
            throw PushoverKeychainError(status: errSecParam)
        }
        var query = Self.itemAttributes(account: account)
        let data = Data(value.utf8)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw PushoverKeychainError(status: updateStatus)
        }
        query[kSecValueData as String] = data
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw PushoverKeychainError(status: addStatus)
        }
    }

    private func load(account: Account) throws -> String? {
        var query = Self.itemAttributes(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne as String
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = result as? Data,
              data.count <= 1_024,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            throw PushoverKeychainError(status: status == errSecSuccess ? errSecDecode : status)
        }
        return value
    }
}

public struct PushoverKeychainError: Error, Equatable, Sendable {
    public let status: OSStatus

    public init(status: OSStatus) {
        self.status = status
    }
}
