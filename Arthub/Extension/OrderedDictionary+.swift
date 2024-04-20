//
//  OrderedDictionary+.swift
//  Arthub
//
//  Created by 张鸿燊 on 27/2/2024.
//

import OrderedCollections

extension OrderedDictionary where Key == String,
                                  Value: RandomAccessCollection,
                                  Value.Element: Identifiable {
    
    func indexOf(id: Value.Element.ID?) -> (keyIndex: Int?, valueIndex: Int?) {
        var keyIndex: Int? = nil, valueIndex: Int? = nil
        outerLoop: for i in 0..<self.elements.count {
            let pair = self.elements[i]
            for j in 0..<pair.value.count {
                if pair.value[_offset: j].id == id {
                    keyIndex = i
                    valueIndex = j
                    break outerLoop
                }
            }
        }
        return (keyIndex, valueIndex)
    }
    
    func id(after id: Value.Element.ID?) -> Value.Element.ID? {
        let (keyIndex, valueIndex) = self.indexOf(id: id)
        
        guard let keyIndex = keyIndex, let valueIndex = valueIndex else {
            return nil
        }
        let nextValueIndex = valueIndex + 1
        if nextValueIndex < self.elements[keyIndex].value.count{
            return self.elements[keyIndex]
                .value[_offset: nextValueIndex].id
        }
        let nextKeyIndex = ( keyIndex + 1 ) % self.count
        return self.elements[nextKeyIndex].value.first?.id
    }
    
    func id(before id: Value.Element.ID?) -> Value.Element.ID? {
        let (keyIndex, valueIndex) = self.indexOf(id: id)
        
        guard let keyIndex = keyIndex, let valueIndex = valueIndex else {
            return nil
        }
        let previousValueIndex = valueIndex - 1
        if previousValueIndex >= 0 {
            return self.elements[keyIndex].value[_offset: previousValueIndex].id
        }
        let previousKeyIndex = ( keyIndex - 1 + self.count) % self.count
        return self.elements[previousKeyIndex].value.last?.id
    }
    
}
