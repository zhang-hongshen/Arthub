//
//  KeychainStorage.swift
//  Arthub
//
//  Created by 张鸿燊 on 19/2/2024.
//

import SwiftUI
import KeychainAccess

//@propertyWrapper
//struct KeychainStorage<T: Codable>: DynamicProperty {
//    
//    typealias Value = T
//    let key: String
//
//
//    init(_ key: String) {
//        self.key = key
//    }
//    var wrappedValue: Value {
//        get  {
//            do {
//                guard let value = try Keychain().getDate(key) else {
//                    // get user default value
//                    return
//                }
//                return try JSONDecoder().decode(Value.self, from: value)
//            } catch{
//                print("[KeychainStorage] Keychain().get(\(key)) - \(error.localizedDescription)")
//            }
//        }
//        nonmutating set {
//            do {
//                let encoded = try JSONEncoder().encode(newValue)
//                try Keychain().set(encoded, key: key)
//            } catch let error {
//                try? Keychain().remove(key)
//            }
//        }
//    }
//
//    var projectedValue: Binding<Value> {
//        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
//    }
//    
//}
