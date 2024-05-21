//
//  WOL.swift
//  Toolbox
//
//  Created by Christian Nagel on 21.05.24.
//

import Foundation
import SwiftData

@Model
class WOLDevice {
    @Attribute(.unique) var name: String
    var mac: String
    var broadcast: String
    var port: Int?
    var lastUsed: Date
    
    init(name: String, mac: String, broadcast: String, port: Int = 9) {
        self.name = name
        self.mac = mac
        self.broadcast = broadcast
        self.port = port
        self.lastUsed = Date()
    }
    
}
