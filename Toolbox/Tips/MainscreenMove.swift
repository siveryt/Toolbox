//
//  MainscreenMove.swift
//  Toolbox
//
//  Created by Christian Nagel on 10.05.24.
//

import Foundation
import TipKit

struct MainscreenMoveTip: Tip {
    
    static let appStarted = Event(id: "mainscreenAppStarted")
    
    var title: Text {
        Text("Move Tools Around")
    }
    
    public var message: Text? {
        Text("Press and hold a tool to move it around as you like")
    }
    
    var image: Image? {
            Image(systemName: "text.line.first.and.arrowtriangle.forward")
        }
    
    
    // No MaxDisplayCount: TipKit counts the tip as shown even while the What's New sheet covers it,
    // so it would be used up unseen. It stays until it's closed or a tool is moved.
    var rules: [Rule] {
        #Rule(Self.appStarted) { $0.donations.count >= 10 }
    }
    
}
