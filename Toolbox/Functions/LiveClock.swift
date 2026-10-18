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

    @AppStorage("liveClockShowUTC") var showUTC: Bool = false

    /// The start of the second the view appeared in. The timeline ticks on whole seconds from there,
    /// so the shown second changes together with the real one.
    @State private var timelineStart = Date(timeIntervalSinceReferenceDate: Date().timeIntervalSinceReferenceDate.rounded(.down))

    /// The offset of the local time zone from UTC at `date`, formatted as e.g. "+02:00".
    func utcOffsetString(at date: Date) -> String {
        let seconds = TimeZone.current.secondsFromGMT(for: date)
        let sign = seconds >= 0 ? "+" : "-"
        let absSeconds = abs(seconds)
        let hours = absSeconds / 3600
        let minutes = (absSeconds % 3600) / 60
        return String(format: "%@%02d:%02d", sign, hours, minutes)
    }

    var body: some View {
        GeometryReader { geometry in
            let base = min(geometry.size.width, geometry.size.height)
            TimelineView(.periodic(from: timelineStart, by: 1)) { context in
                let now = context.date
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
                            Text(String(format: NSLocalizedString("Local time: UTC%@", comment: "Live Clock: line below the UTC time showing the local time zone's offset from UTC; %@ is the offset, e.g. \"+02:00\""), utcOffsetString(at: now)))
                                .font(.system(size: base * 0.07, design: .default)).monospacedDigit()
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.01)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding() // Adds default padding
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Live Clock")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showUTC.toggle()
                    }
                } label: {
                    Label(NSLocalizedString("Show UTC", comment: "Live Clock setting"), systemImage: "globe")
                }
                .tint(showUTC ? .accentColor : .primary)
            }
        }
    }
}

struct LiveClock_Previews: PreviewProvider {
    static var previews: some View {
        LiveClock()
    }
}
