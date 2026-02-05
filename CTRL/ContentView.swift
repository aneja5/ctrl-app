import SwiftUI

struct ScanRecord: Identifiable {
    let id = UUID()
    let tagID: String
    let timestamp: Date
}

struct ContentView: View {
    @StateObject private var nfcManager = NFCManager()
    @State private var scanHistory: [ScanRecord] = []
    @State private var showCopied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Status Card
                    statusCard

                    // Scan Button
                    scanButton

                    // Scanning Indicator
                    if nfcManager.isScanning {
                        scanningIndicator
                    }

                    // Last Scanned Tag Card
                    if let lastTagID = nfcManager.lastTagID {
                        lastTagCard(tagID: lastTagID)
                    }

                    // Error Message
                    if let errorMessage = nfcManager.errorMessage {
                        errorCard(message: errorMessage)
                    }

                    // Scan History
                    if !scanHistory.isEmpty {
                        historySection
                    }

                    Spacer(minLength: 40)

                    // Footer
                    footer
                }
                .padding()
            }
            .navigationTitle("CTRL")
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        HStack {
            Image(systemName: nfcManager.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(nfcManager.isAvailable ? .green : .red)
                .font(.title2)

            Text(nfcManager.isAvailable ? "NFC Available" : "NFC Not Available")
                .font(.headline)

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Scan Button

    private var scanButton: some View {
        Button(action: performScan) {
            HStack {
                Image(systemName: "wave.3.right")
                Text("Scan NFC Tag")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(nfcManager.isScanning ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(nfcManager.isScanning || !nfcManager.isAvailable)
    }

    // MARK: - Scanning Indicator

    private var scanningIndicator: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Text("Scanning...")
                .foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - Last Tag Card

    private func lastTagCard(tagID: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Scanned Tag")
                .font(.headline)
                .foregroundColor(.secondary)

            HStack {
                Text(tagID)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button(action: { copyToClipboard(tagID) }) {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .foregroundColor(showCopied ? .green : .blue)
                        .font(.title3)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Error Card

    private func errorCard(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.orange)

            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scan History")
                .font(.headline)
                .foregroundColor(.secondary)

            ForEach(scanHistory) { record in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.tagID)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Text(record.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 4) {
            Text("CTRL - Day 1 Test Build")
                .font(.footnote)
                .foregroundColor(.secondary)

            Text("getctrl.in")
                .font(.footnote)
                .foregroundColor(.blue)
        }
    }

    // MARK: - Actions

    private func performScan() {
        nfcManager.scan { result in
            switch result {
            case .success(let tagID):
                let record = ScanRecord(tagID: tagID, timestamp: Date())
                scanHistory.insert(record, at: 0)

                // Keep only last 10 scans
                if scanHistory.count > 10 {
                    scanHistory = Array(scanHistory.prefix(10))
                }

            case .failure(let error):
                print("Scan failed: \(error.localizedDescription)")
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        showCopied = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }
}

#Preview {
    ContentView()
}
