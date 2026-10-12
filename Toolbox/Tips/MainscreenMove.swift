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
    
    
    var options: [TipOption] = [MaxDisplayCount(1)]
    
    var rules: [Rule] {
        #Rule(Self.appStarted) { $0.donations.count >= 10 }
    }
    
}
