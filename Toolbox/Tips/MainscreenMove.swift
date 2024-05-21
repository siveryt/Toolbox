//
//  MainscreenMove.swift
//  Toolbox
//
//  Created by Christian Nagel on 10.05.24.
//

import Foundation
import TipKit

struct MainscreenMoveTip: Tip {
    
    @Parameter
    static var hasAlreadyMoved: Bool = false
    
    @Parameter
    static var appStarts: Int = 0
    
    var title: Text {
        Text("Move tools around")
    }
    
    public var message: Text? {
        Text("Press and hold a feature to move it around as you like")
    }
    
    var image: Image? {
            Image(systemName: "text.line.first.and.arrowtriangle.forward")
        }
    
    
    var options: [TipOption] = [MaxDisplayCount(1)]
    
    var rules: [Rule] {
        #Rule(Self.$hasAlreadyMoved) { $0 == false }
        #Rule(Self.$appStarts) { $0 > 5 }
    }
    
}
