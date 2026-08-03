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

    func getFormattedDate(format: String, timeZone: TimeZone) -> String {
        let dateformat = DateFormatter()
        dateformat.dateFormat = format
        dateformat.timeZone = timeZone
        return dateformat.string(from: self)
    }
}

struct LiveClock: View {

    @State var now = Date()

    @AppStorage("liveClockShowUTC") var showUTC: Bool = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// The current offset of the local time zone from UTC, formatted as e.g. "+02:00".
    var utcOffsetString: String {
        let seconds = TimeZone.current.secondsFromGMT(for: now)
        let sign = seconds >= 0 ? "+" : "-"
        let absSeconds = abs(seconds)
        let hours = absSeconds / 3600
        let minutes = (absSeconds % 3600) / 60
        return String(format: "%@%02d:%02d", sign, hours, minutes)
    }

    var body: some View {
        GeometryReader { geometry in
            let base = min(geometry.size.width, geometry.size.height)
            VStack(spacing: base * 0.06) {
                Text(now.getFormattedDate(format: "HH:mm:ss"))
                    .font(.system(size: base * (showUTC ? 0.45 : 0.8), design: .default)).monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.01)

                if showUTC {
                    VStack(spacing: base * 0.02) {
                        Text(now.getFormattedDate(format: "HH:mm:ss", timeZone: TimeZone(identifier: "UTC")!))
                            .font(.system(size: base * 0.2, design: .default)).monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.01)
                        Text("\(NSLocalizedString("Local time", comment: "Live Clock")): UTC\(utcOffsetString)")
                            .font(.system(size: base * 0.07, design: .default)).monospacedDigit()
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.01)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding() // Adds default padding
            .onReceive(timer) { input in
                now = input
            }
            .onDisappear {
                timer.upstream.connect().cancel()
            }
            .onAppear {
                now = Date()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Live Clock")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Toggle(isOn: $showUTC) {
                        Label(NSLocalizedString("Show UTC", comment: "Live Clock setting"), systemImage: "globe")
                    }
                } label: {
                    Label(NSLocalizedString("Settings", comment: "Live Clock setting"), systemImage: "ellipsis.circle")
                }
            }
        }
    }
}

struct LiveClock_Previews: PreviewProvider {
    static var previews: some View {
        LiveClock()
    }
}
