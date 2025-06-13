//
//  Item.swift
//  IAmListening
//
//  Created by k k on 2025/6/7.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
