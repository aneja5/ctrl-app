import SwiftUI

struct TokenHistoryView: View {
    @State private var history: [TokenHistoryEntry] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("History")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "E8E0D8"))

                Spacer()

                if !history.isEmpty {
                    Button("Export") {
                        exportHistory()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "A68A64"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)

            // Content
            if history.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(history) { entry in
                            historyRow(entry: entry)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
        }
        .onAppear {
            loadHistory()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color(hex: "6F675E"))

            Text("No tokens written yet")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "A89F94"))
        }
    }

    private func historyRow(entry: TokenHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.uuid.prefix(8) + "...")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Color(hex: "E8E0D8"))

                Spacer()

                Text(formatDate(entry.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "6F675E"))
            }

            Text(entry.fullPayload)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(hex: "6F675E"))
                .lineLimit(1)
        }
        .padding(16)
        .background(Color(hex: "1E1915"))
        .cornerRadius(12)
        .contextMenu {
            Button("Copy Full Payload") {
                UIPasteboard.general.string = entry.fullPayload
            }
            Button("Copy UUID") {
                UIPasteboard.general.string = entry.uuid
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: "token_history"),
              let decoded = try? JSONDecoder().decode([TokenHistoryEntry].self, from: data) else {
            return
        }
        history = decoded
    }

    private func exportHistory() {
        let csv = history.map { "\($0.uuid),\($0.fullPayload),\($0.createdAt)" }.joined(separator: "\n")
        UIPasteboard.general.string = "UUID,Payload,Created\n" + csv

        // Show feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
