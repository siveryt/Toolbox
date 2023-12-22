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
        
        GeometryReader { geometry in
            Text(now.getFormattedDate(format: "HH:mm:ss"))
                .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.8, design: .default)).monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.01)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding() // Adds default padding
                .onAppear(perform: {self.now = Date(); let _ = self.updateTimer})
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        Text(now.getFormattedDate(format: "HH:mm:ss"))
//            .onAppear(perform: {self.now = Date(); let _ = self.updateTimer})
//            .font(.system(size: calculateFontSize()))
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Live Clock")
        
    }
    var updateTimer: Timer {
        Timer.scheduledTimer(withTimeInterval: 0.001, repeats: true,
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
