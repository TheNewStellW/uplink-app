//
//  Item.swift
//  Transmission Remote
//
//  Created by Stellios Williams on 31/3/2026.
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
