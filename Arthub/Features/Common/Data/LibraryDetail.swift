//
//  LibraryDetail.swift
//  Arthub
//
//  Created by 张鸿燊 on 21/3/2024.
//

import Foundation
import SwiftData


enum ProtocolType: Int, Identifiable, CaseIterable {
    case webdav, webdavs
    var id: Self { self }
    
    var localizedName: String {
        switch self {
        case .webdav:
            "WebDAV"
        case .webdavs:
            "WebDAVs"
        }
    }
    
    var scheme: String {
        switch self {
        case .webdav:
            "http"
        case .webdavs:
            "https"
        }
    }
}

@Model
class LibraryDetail: Identifiable {
    
    @Attribute(.unique) let id = UUID()
    var title: String
    var url: String
    var username: String
    var password: String
    private var protocolID: Int
    @Transient var protocolType: ProtocolType {
        get { return ProtocolType(rawValue: protocolID) ?? .webdav }
        set { self.protocolID = newValue.rawValue }
    }
    
    init(title: String = "", url: String = "", username: String = "",
         password: String = "", protocolType: ProtocolType = .webdav) {
        self.title = title
        self.url = url
        self.username = username
        self.password = password
        self.protocolID = protocolType.rawValue
    }
}
