//
//  LiveClock.swift
//  Toolbox
//
//  Created by Christian Nagel on 20.03.22.
//

import SwiftUI

extension Date {
    func getFormattedDate(format: String) -> String {
        let dateformat = DateFormatter()
        dateformat.dateFormat = format
        return dateformat.string(from: self)
    }
}


struct LiveClock: View {
    
    @State var now = Date()
    
    var body: some View {
        Text(now.getFormattedDate(format: "HH:mm:ss"))
            .onAppear(perform: {self.now = Date(); let _ = self.updateTimer})
            .dynamicTypeSize(/*@START_MENU_TOKEN@*/.accessibility5/*@END_MENU_TOKEN@*/)
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Live Clock")
        
    }
    var updateTimer: Timer {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true,
                             block: {_ in
            self.now = Date()
        })
    }
    
    
}

struct LiveClock_Previews: PreviewProvider {
    static var previews: some View {
        LiveClock()
    }
}
