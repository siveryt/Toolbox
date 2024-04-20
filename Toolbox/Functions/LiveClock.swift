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
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            Text(now.getFormattedDate(format: "HH:mm:ss"))
                .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.8, design: .default)).monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.01)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding() // Adds default padding
                .onReceive(timer) { input in
                    now = input
                }
                .onDisappear {
                    timer.upstream.connect().cancel()
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Live Clock")
        
    }
}

struct LiveClock_Previews: PreviewProvider {
    static var previews: some View {
        LiveClock()
    }
}
