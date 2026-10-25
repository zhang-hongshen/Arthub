//
//  RemoteFolder.swift
//  Arthub
//

import Foundation
import Security
#if os(macOS)
import NetFS
#endif

/// SMB and WebDAV folders, e.g. `smb://nas.local/Media/Movies` or `https://nas.local:5006/Movies`.
/// The system mounts the share, so the library reads, plays and tags its files like local ones.
enum RemoteFolder {
    static let schemes = ["smb", "http", "https"]

    static func isRemote(_ library: String) -> Bool {
        guard let scheme = URL(string: library)?.scheme?.lowercased() else { return false }
        return schemes.contains(scheme)
    }

    /// Builds the library entry from what the user typed. The password never goes into it.
    static func library(address: String, user: String) -> String? {
        var text = address.trimmingCharacters(in: .whitespaces)
        if !text.contains("://") { text = "smb://" + text }
        guard let url = URL(string: text, encodingInvalidCharacters: true),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(), schemes.contains(scheme),
              components.host?.isEmpty == false else { return nil }
        // An SMB address must name a share, e.g. `smb://nas.local/Media`.
        if scheme == "smb" && url.path(percentEncoded: false).split(separator: "/").isEmpty { return nil }
        components.scheme = scheme
        components.password = nil
        if !user.isEmpty { components.user = user }
        while components.path.hasSuffix("/") { components.path.removeLast() }
        return components.string
    }

    /// The local folder of `library`, mounting its share first when it is not mounted yet.
    static func folder(for library: String) async throws -> URL {
        try await mount(library, password: password(for: library))
    }

    /// Mounts a new server folder and remembers its password once the folder is reachable.
    static func connect(_ library: String, password: String) async throws {
        let folder = try await mount(library, password: password)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory),
              isDirectory.boolValue else { throw RemoteFolderError.folderMissing }
        savePassword(password, for: library)
    }

    static func forget(_ library: String) {
        SecItemDelete(keychainQuery(for: library) as CFDictionary)
    }

    private static func mount(_ library: String, password: String?) async throws -> URL {
        #if os(macOS)
        guard let url = URL(string: library) else { throw RemoteFolderError.badAddress }
        let (share, folder) = share(of: url)
        let mountPoint = try await Task.detached {
            try mountedVolume(for: share) ?? mountShare(share, password: password)
        }.value
        return folder.isEmpty ? mountPoint : mountPoint.appending(path: folder, directoryHint: .isDirectory)
        #else
        throw RemoteFolderError.unsupported
        #endif
    }

    /// SMB mounts `smb://host/share`, and the rest of the path is a folder inside it.
    /// WebDAV mounts the whole address.
    private static func share(of url: URL) -> (share: URL, folder: String) {
        let parts = url.path(percentEncoded: false).split(separator: "/")
        guard url.scheme?.lowercased() == "smb", let first = parts.first,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return (url, "") }
        components.path = "/" + first
        return (components.url ?? url, parts.dropFirst().joined(separator: "/"))
    }

    #if os(macOS)
    /// A share the user already mounted in Finder is used as it is.
    private static func mountedVolume(for share: URL) -> URL? {
        let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeURLForRemountingKey], options: []) ?? []
        return volumes.first { volume in
            guard let remote = try? volume.resourceValues(forKeys: [.volumeURLForRemountingKey])
                .volumeURLForRemounting else { return false }
            return remote.scheme?.lowercased() == share.scheme?.lowercased() &&
                remote.host()?.lowercased() == share.host()?.lowercased() &&
                remote.port == share.port &&
                trimmedPath(remote) == trimmedPath(share)
        }
    }

    private static func trimmedPath(_ url: URL) -> String {
        url.path(percentEncoded: false).trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
    }

    private static func mountShare(_ share: URL, password: String?) throws -> URL {
        let openOptions = NSMutableDictionary()
        openOptions[kNAUIOptionKey as String] = kNAUIOptionNoUI as String
        let user = share.user(percentEncoded: false)
        if user == nil && share.scheme?.lowercased() == "smb" {
            openOptions[kNetFSUseGuestKey as String] = true
        }
        var mountPoints: Unmanaged<CFArray>?
        let status = NetFSMountURLSync(share as CFURL, nil, user as CFString?, password as CFString?,
                                       openOptions as CFMutableDictionary, nil, &mountPoints)
        let paths = mountPoints?.takeRetainedValue() as? [String]
        guard status == 0, let path = paths?.first else {
            throw status == EAUTH || status == EACCES
                ? RemoteFolderError.authentication : RemoteFolderError.mountFailed(status)
        }
        return URL(filePath: path, directoryHint: .isDirectory)
    }
    #endif

    // MARK: Keychain

    private static func keychainQuery(for library: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "Arthub Server",
         kSecAttrAccount as String: library]
    }

    private static func password(for library: String) -> String? {
        var query = keychainQuery(for: library)
        query[kSecReturnData as String] = true
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private static func savePassword(_ password: String, for library: String) {
        forget(library)
        guard !password.isEmpty else { return }
        var item = keychainQuery(for: library)
        item[kSecValueData as String] = Data(password.utf8)
        SecItemAdd(item as CFDictionary, nil)
    }
}

enum RemoteFolderError: LocalizedError {
    case badAddress, authentication, folderMissing, unsupported
    case mountFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .badAddress: String(localized: "Enter an address such as smb://nas.local/Media or https://nas.local/Media.")
        case .authentication: String(localized: "The user name or password is incorrect.")
        case .folderMissing: String(localized: "This folder was not found on the server.")
        case .unsupported: String(localized: "Network servers are only supported on Mac.")
        case .mountFailed(let status): String(localized: "Unable to connect to the server (error \(Int(status))).")
        }
    }
}
