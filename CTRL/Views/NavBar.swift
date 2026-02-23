import SwiftUI

struct NavBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            navItem(label: "home", icon: "house", tag: 0)
            navItem(label: "stats", icon: "chart.bar", tag: 1)
            navItem(label: "settings", icon: "gearshape", tag: 2)
        }
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(
            CTRLColors.base
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func navItem(label: String, icon: String, tag: Int) -> some View {
        let isActive = selectedTab == tag

        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedTab = tag
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isActive ? "\(icon).fill" : icon)
                    .font(.system(size: 20))

                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(isActive ? CTRLColors.accent : Color.white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
    }
}
