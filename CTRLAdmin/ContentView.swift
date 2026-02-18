import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            Color(hex: "14110F")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                switch selectedTab {
                case 0:
                    NFCWriterView()
                case 1:
                    TokenHistoryView()
                case 2:
                    TokenVerifyView()
                default:
                    NFCWriterView()
                }
            }
            .safeAreaInset(edge: .bottom) {
                customTabBar
            }
        }
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton(icon: "wave.3.right", label: "Write", index: 0)
            tabButton(icon: "list.bullet", label: "History", index: 1)
            tabButton(icon: "checkmark.shield", label: "Verify", index: 2)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color(hex: "1E1915").ignoresSafeArea(edges: .bottom))
    }

    private func tabButton(icon: String, label: String, index: Int) -> some View {
        Button(action: {
            selectedTab = index
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(selectedTab == index ? Color(hex: "A68A64") : Color(hex: "6F675E"))
            .frame(maxWidth: .infinity)
        }
    }
}

// Color extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}
