//
//  FilePath.swift
//  SingBoxPacketTunnel
//
//  Created by GFWFighter on 7/25/1402 AP.
//

import Foundation
import Security

public enum FilePath {
    public static let packageName = {
        Bundle.main.infoDictionary?["BASE_BUNDLE_IDENTIFIER"] as? String ?? "unknown"
    }()
}

public extension FilePath {
    private static let grpcCredentialLock = NSLock()

    static func grpcSecret() throws -> String {
        grpcCredentialLock.lock()
        defer { grpcCredentialLock.unlock() }
        guard let storage = UserDefaults(suiteName: groupName) else {
            throw NSError(domain: "CoreCredentials", code: 1)
        }
        if let secret = storage.string(forKey: "grpc_auth_secret"), secret.count >= 32 {
            return secret
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw NSError(domain: "CoreCredentials", code: 2)
        }
        let secret = Data(bytes).base64EncodedString()
        storage.set(secret, forKey: "grpc_auth_secret")
        return secret
    }

    static let groupName = "group.\(packageName)"

    private static let defaultSharedDirectory: URL! = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: FilePath.groupName)

    static let sharedDirectory = defaultSharedDirectory!

    static let cacheDirectory = sharedDirectory
        .appendingPathComponent("Library", isDirectory: true)
        .appendingPathComponent("Caches", isDirectory: true)

    static let workingDirectory = cacheDirectory.appendingPathComponent("Working", isDirectory: true)
}

public extension URL {
    var fileName: String {
        var path = relativePath
        if let index = path.lastIndex(of: "/") {
            path = String(path[path.index(index, offsetBy: 1)...])
        }
        return path
    }
}
