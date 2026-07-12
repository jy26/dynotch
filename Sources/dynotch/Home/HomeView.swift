import SwiftUI

/// Default landing surface (Home): a clock with the date + greeting. The tab the
/// notch opens on when nothing is playing and no timer is running. Framed to
/// `ScreenGeometry.expandedSize` by `NotchView`, gated to the `.home` tab.
/// (Battery/timer glances live on the activities tab — Home stays uncluttered;
/// a weather widget is a natural future addition here.)
struct HomeView: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            VStack(spacing: 3) {
                Text(now, format: .dateTime.hour().minute())
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(greeting(now)) · \(now.formatted(.dateTime.weekday(.wide).month().day()))")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.top, 40)            // clears the notch strip + tab bar
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func greeting(_ date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case ..<12:   return "Good morning"
        case 12..<18: return "Good afternoon"
        default:      return "Good evening"
        }
    }
}
